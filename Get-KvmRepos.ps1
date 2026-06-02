<#
.SYNOPSIS
    Clona os repositórios do ecossistema KVM/QEMU/libvirt na última tag estável.

.DESCRIPTION
    Baixa o código-fonte dos componentes que formam a camada de virtualização KVM:
      - Linux kernel  (sparse checkout: apenas virt/kvm, arch/x86/kvm, include, Documentation/virt)
      - QEMU          (emulador completo)
      - libvirt       (API de gerenciamento — usada pelo Nova)
      - libvirt-python (bindings Python usados pelo Nova/OpenStack)

    Para cada repositório, descobre dinamicamente a última tag estável via
    "git ls-remote --tags" e faz um clone superficial (--depth 1) por padrão.

.PARAMETER OutputDir
    Diretório raiz onde os repositórios serão clonados.
    Padrão: ".\kvm-repos"

.PARAMETER Shallow
    $true  → clone superficial (--depth 1 + --branch <tag>). Recomendado. (padrão)
    $false → clone completo com histórico inteiro.

.PARAMETER ThrottleLimit
    Número de clones simultâneos (PowerShell 7 ForEach-Object -Parallel).
    Padrão: 3 (repos grandes — não adianta paralelizar além da largura de banda).

.PARAMETER SkipKernel
    Pula o clone do Linux kernel (útil se só quer QEMU + libvirt).
    O kernel é o maior dos repos (~200 MB em sparse clone).

.EXAMPLE
    .\Get-KvmRepos.ps1                          # tudo, shallow, destino .\kvm-repos
    .\Get-KvmRepos.ps1 -Shallow $false          # clone completo (lento)
    .\Get-KvmRepos.ps1 -SkipKernel              # QEMU + libvirt + libvirt-python apenas
    .\Get-KvmRepos.ps1 -OutputDir D:\kvm        # destino alternativo

.NOTES
    Requer: git >= 2.25 no PATH (para sparse-checkout cone mode), PowerShell 7+
    Relatório CSV salvo em: <OutputDir>\_summary.csv
#>

[CmdletBinding()]
param(
    [string] $OutputDir     = ".\repos\kvm",
    [int]    $ThrottleLimit = 3,
    [bool]   $Shallow       = $true,
    [switch] $SkipKernel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
$env:GIT_TERMINAL_PROMPT = "0"   # evita prompts interativos de credencial

# ─────────────────────────────────────────────────────────────────────────────
# Definição dos repositórios
# ─────────────────────────────────────────────────────────────────────────────

$REPOS = @(
    [PSCustomObject]@{
        Name        = "linux"
        Url         = "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
        TagPattern  = '^v6\.\d+(\.\d+)?$'          # v6.x ou v6.x.y — sem -rc
        TagSort     = "version"
        Sparse      = $true
        SparsePaths = @(
            "virt/kvm",
            "arch/x86/kvm",
            "arch/arm64/kvm",
            "include/linux",
            "include/uapi/linux",
            "Documentation/virt/kvm"
        )
        Skip        = $SkipKernel.IsPresent
    },
    [PSCustomObject]@{
        Name        = "qemu"
        Url         = "https://gitlab.com/qemu-project/qemu.git"
        TagPattern  = '^v\d+\.\d+\.\d+$'            # v9.2.0 — sem -rc
        TagSort     = "version"
        Sparse      = $false
        SparsePaths = @()
        Skip        = $false
    },
    [PSCustomObject]@{
        Name        = "libvirt"
        Url         = "https://gitlab.com/libvirt/libvirt.git"
        TagPattern  = '^v\d+\.\d+\.\d+$'            # v10.0.0 — sem -rc
        TagSort     = "version"
        Sparse      = $false
        SparsePaths = @()
        Skip        = $false
    },
    [PSCustomObject]@{
        Name        = "libvirt-python"
        Url         = "https://gitlab.com/libvirt/libvirt-python.git"
        TagPattern  = '^v\d+\.\d+\.\d+$'
        TagSort     = "version"
        Sparse      = $false
        SparsePaths = @()
        Skip        = $false
    }
)

# ─────────────────────────────────────────────────────────────────────────────
# Funções auxiliares
# ─────────────────────────────────────────────────────────────────────────────

function Write-Status {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor $Color
}

function Get-LatestTag {
    <#
    Descobre a última tag estável de um repositório via "git ls-remote --tags".
    Retorna a string da tag (ex: "v6.14.5") ou $null em caso de falha.
    #>
    param(
        [string]$Url,
        [string]$Pattern,
        [string]$Sort = "version"
    )

    try {
        $rawTags = & git ls-remote --tags --refs $Url 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "git ls-remote falhou para $Url"
            return $null
        }

        $tags = $rawTags |
            ForEach-Object { ($_ -split '\s+')[1] -replace '^refs/tags/', '' } |
            Where-Object { $_ -match $Pattern } |
            Sort-Object { [System.Version]($_ -replace '^v', '' -replace '-.*', '') } |
            Select-Object -Last 1

        return $tags
    }
    catch {
        Write-Warning "Erro ao buscar tags de $Url : $_"
        return $null
    }
}

function Invoke-StandardClone {
    param([string]$Url, [string]$Tag, [string]$Dest, [bool]$UseShallow)

    $gitArgs = @("clone", "--quiet")
    if ($UseShallow) { $gitArgs += @("--depth", "1") }
    $gitArgs += @("--branch", $Tag, $Url, $Dest)

    $output   = & git @gitArgs 2>&1
    $exitCode = $LASTEXITCODE
    return @{ Output = $output; ExitCode = $exitCode }
}

function Invoke-SparseClone {
    <#
    Clona apenas os caminhos especificados usando --filter=blob:none + sparse-checkout.
    Muito mais eficiente para o kernel Linux (evita baixar 3 GB+ de blobs).
    #>
    param(
        [string]   $Url,
        [string]   $Tag,
        [string]   $Dest,
        [string[]] $Paths,
        [bool]     $UseShallow
    )

    # 1. Clone blobless + sparse init
    $cloneArgs = @("clone", "--filter=blob:none", "--sparse", "--quiet")
    if ($UseShallow) { $cloneArgs += @("--depth", "1") }
    $cloneArgs += @("--branch", $Tag, $Url, $Dest)

    $output   = & git @cloneArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        return @{ Output = $output; ExitCode = $exitCode }
    }

    # 2. Configurar sparse-checkout (cone mode)
    & git -C $Dest sparse-checkout init --cone 2>&1 | Out-Null
    $scOutput   = & git -C $Dest sparse-checkout set @Paths 2>&1
    $scExitCode = $LASTEXITCODE

    return @{ Output = ($output + $scOutput); ExitCode = $scExitCode }
}

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────

$banner = @"

  ╔═══════════════════════════════════════════════════╗
  ║        KVM / QEMU / libvirt Repository Cloner     ║
  ╠═══════════════════════════════════════════════════╣
  ║  Destino      : $($OutputDir.PadRight(33))║
  ║  Modo clone   : $($(if ($Shallow) { 'shallow (--depth 1)                   ' } else { 'completo (histórico inteiro)   ' }).PadRight(33))║
  ║  Paralelismo  : $("$ThrottleLimit workers".PadRight(33))║
  ║  Skip kernel  : $("$($SkipKernel.IsPresent)".PadRight(33))║
  ╚═══════════════════════════════════════════════════╝

"@
Write-Host $banner -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# Verificações iniciais
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git não encontrado no PATH."
    exit 1
}

$gitVersion = (& git --version) -replace 'git version ', ''
Write-Status "git $gitVersion detectado."

$resolvedOut = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
New-Item -ItemType Directory -Path $resolvedOut -Force | Out-Null

# ─────────────────────────────────────────────────────────────────────────────
# Descoberta de tags (sequencial — chamadas de rede independentes mas rápidas)
# ─────────────────────────────────────────────────────────────────────────────

Write-Status "Descobrindo últimas tags estáveis..."

$activeRepos = $REPOS | Where-Object { -not $_.Skip }

foreach ($repo in $activeRepos) {
    Write-Host "  → $($repo.Name) ... " -NoNewline -ForegroundColor DarkCyan
    $tag = Get-LatestTag -Url $repo.Url -Pattern $repo.TagPattern -Sort $repo.TagSort
    if ($tag) {
        $repo | Add-Member -NotePropertyName "Tag" -NotePropertyValue $tag -Force
        Write-Host $tag -ForegroundColor Green
    }
    else {
        Write-Host "FALHA (tag não encontrada)" -ForegroundColor Red
        $repo | Add-Member -NotePropertyName "Tag" -NotePropertyValue "" -Force
    }
}

$validRepos = @($activeRepos | Where-Object { $_.Tag -ne "" })

if ($validRepos.Count -eq 0) {
    Write-Error "Nenhum repositório com tag válida encontrado. Verifique conectividade."
    exit 1
}

Write-Host ""
Write-Status "$($validRepos.Count) repositório(s) prontos para clone."
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# Clone em paralelo
# ─────────────────────────────────────────────────────────────────────────────

$cloneResults = $validRepos | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {

    $repo        = $_
    $baseDir     = $using:resolvedOut
    $useShallow  = $using:Shallow

    $destDir = Join-Path $baseDir $repo.Name

    $result = [PSCustomObject]@{
        Name   = $repo.Name
        Tag    = $repo.Tag
        Dest   = $destDir
        Status = "pending"
        Error  = ""
    }

    # Já clonado?
    if (Test-Path (Join-Path $destDir ".git")) {
        $result.Status = "skipped"
        Write-Host "  [~] $($repo.Name)  @$($repo.Tag)  (já existe)" -ForegroundColor Yellow
        return $result
    }

    # ── Funções internas (ForEach-Object -Parallel não herda funções do escopo pai) ──

    function Do-StandardClone($Url, $Tag, $Dest, $Shallow) {
        $args = @("clone", "--quiet")
        if ($Shallow) { $args += @("--depth", "1") }
        $args += @("--branch", $Tag, $Url, $Dest)
        $out = & git @args 2>&1
        return @{ Output = $out; ExitCode = $LASTEXITCODE }
    }

    function Do-SparseClone($Url, $Tag, $Dest, $Paths, $Shallow) {
        $args = @("clone", "--filter=blob:none", "--sparse", "--quiet")
        if ($Shallow) { $args += @("--depth", "1") }
        $args += @("--branch", $Tag, $Url, $Dest)
        $out = & git @args 2>&1
        if ($LASTEXITCODE -ne 0) { return @{ Output = $out; ExitCode = $LASTEXITCODE } }
        & git -C $Dest sparse-checkout init --cone 2>&1 | Out-Null
        $scOut = & git -C $Dest sparse-checkout set @Paths 2>&1
        return @{ Output = ($out + $scOut); ExitCode = $LASTEXITCODE }
    }

    # ── Executar clone ──

    try {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        if ($repo.Sparse) {
            $r = Do-SparseClone -Url $repo.Url -Tag $repo.Tag -Dest $destDir `
                                -Paths $repo.SparsePaths -Shallow $useShallow
        }
        else {
            $r = Do-StandardClone -Url $repo.Url -Tag $repo.Tag -Dest $destDir `
                                  -Shallow $useShallow
        }

        if ($r.ExitCode -eq 0) {
            $result.Status = "cloned"
            Write-Host "  [+] $($repo.Name)  @$($repo.Tag)  $(if ($repo.Sparse) { '(sparse)' })" -ForegroundColor Green
        }
        else {
            $errMsg = ($r.Output | Out-String).Trim() -replace "`n", " "
            $result.Status = "error"
            $result.Error  = $errMsg
            if ((Get-ChildItem $destDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
                Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Host "  [!] $($repo.Name)  @$($repo.Tag) — ERRO: $errMsg" -ForegroundColor Red
        }
    }
    catch {
        $result.Status = "error"
        $result.Error  = $_.ToString()
        Write-Host "  [!] $($repo.Name) — EXCEÇÃO: $($_.ToString())" -ForegroundColor Red
    }

    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# Relatório final
# ─────────────────────────────────────────────────────────────────────────────

$cloned  = @($cloneResults | Where-Object Status -eq "cloned")
$skipped = @($cloneResults | Where-Object Status -eq "skipped")
$errors  = @($cloneResults | Where-Object Status -eq "error")

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  Resumo Final                                     ║" -ForegroundColor Cyan
Write-Host "  ╠═══════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  Clonados  : $("$($cloned.Count)".PadRight(37))║" -ForegroundColor Green
Write-Host "  ║  Pulados   : $("$($skipped.Count) (já existiam)".PadRight(37))║" -ForegroundColor Yellow
Write-Host "  ║  Erros     : $("$($errors.Count)".PadRight(37))║" -ForegroundColor $(if ($errors.Count -gt 0) { "Red" } else { "Green" })
Write-Host "  ╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "  Repositórios com falha:" -ForegroundColor Red
    $errors | ForEach-Object {
        Write-Host "    $($_.Name)  @$($_.Tag)" -ForegroundColor DarkRed
        Write-Host "      $($_.Error)" -ForegroundColor DarkRed
    }
    Write-Host ""
    Write-Host "  Dica: execute o script novamente — repositórios já clonados serão pulados." -ForegroundColor Yellow
}

# CSV
$csvPath = Join-Path $resolvedOut "_summary.csv"
$cloneResults |
    Select-Object Name, Tag, Status, Dest, Error |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Status "Relatório salvo : $csvPath" "Cyan"
Write-Status "Repositórios em : $resolvedOut" "Cyan"
Write-Host ""
