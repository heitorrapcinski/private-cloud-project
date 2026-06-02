<#
.SYNOPSIS
    Clona todos os repositórios do OpenStack e faz checkout na última tag estável de uma release.

.DESCRIPTION
    Consulta os metadados de release do OpenStack (via GitHub mirror do repo openstack/releases),
    identifica a última versão estável de cada projeto, clona os repositórios a partir do
    servidor oficial (opendev.org) e faz checkout na tag correspondente.

    O script lida com:
      - 200+ projetos em paralelo
      - Retomada: repositórios já clonados são pulados automaticamente
      - Versões de pré-release (RC, alpha, beta) são ignoradas
      - Múltiplos repositórios por deliverable
      - Geração de relatório CSV ao final

.PARAMETER Release
    Codinome da release OpenStack (minúsculas). Exemplos:
      gazpacho  → 2026.1  (padrão — última estável mantida, lançada 2026-04-01)
      flamingo  → 2025.2
      epoxy     → 2025.1
      dalmatian → 2024.2
    Lista completa: https://releases.openstack.org/

.PARAMETER OutputDir
    Diretório raiz onde os repositórios serão clonados.
    Estrutura criada: <OutputDir>/<namespace>/<repo>
    Padrão: ".\openstack-repos"

.PARAMETER ThrottleLimit
    Número de operações de clone simultâneas (PowerShell 7 ForEach-Object -Parallel).
    Valores muito altos podem saturar a rede ou o servidor. Padrão: 4.

.PARAMETER Shallow
    $true  → clone superficial (--depth 1 --branch <tag>). Muito mais rápido,
             ocupa menos disco. Ideal para build, leitura de código. (padrão)
    $false → clone completo com histórico inteiro.

.PARAMETER CloneServer
    Servidor base para git clone.
      opendev  → https://opendev.org  (oficial, padrão)
      github   → https://github.com   (mirror — use se opendev.org estiver lento)

.PARAMETER Filter
    Regex para filtrar repositórios pelo nome completo (ex: "openstack/nova",
    "nova|cinder|neutron"). Se omitido, clona tudo.

.PARAMETER GitHubToken
    Personal Access Token do GitHub para aumentar o rate limit da API
    (60 req/h sem token → 5000 req/h com token).
    O token é usado apenas para a chamada de listagem, não para git clone.

.EXAMPLE
    # Clonar tudo na release padrão (epoxy / 2025.1), clone superficial
    .\Get-OpenStackRepos.ps1

.EXAMPLE
    # Release anterior, clone completo, outro diretório
    .\Get-OpenStackRepos.ps1 -Release dalmatian -Shallow $false -OutputDir D:\openstack

.EXAMPLE
    # Apenas projetos de compute e rede
    .\Get-OpenStackRepos.ps1 -Filter "nova|neutron|cinder|keystone|glance|swift"

.EXAMPLE
    # Via GitHub mirror, com token para evitar rate limit
    .\Get-OpenStackRepos.ps1 -CloneServer github -GitHubToken "ghp_xxxx"

.NOTES
    Requer: git no PATH, PowerShell 7+, acesso à internet
    Relatório CSV salvo em: <OutputDir>\_summary.csv
#>

[CmdletBinding()]
param(
    [string] $Release       = "gazpacho",
    [string] $OutputDir     = ".\repos\openstack",
    [int]    $ThrottleLimit = 4,
    [bool]   $Shallow       = $true,
    [ValidateSet("opendev", "github")]
    [string] $CloneServer   = "opendev",
    [string] $Filter        = "",
    [string] $GitHubToken   = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ─────────────────────────────────────────────────────────────────────────────
# Constantes
# ─────────────────────────────────────────────────────────────────────────────

$GITHUB_API    = "https://api.github.com/repos/openstack/releases/contents/deliverables"
$GITHUB_RAW    = "https://raw.githubusercontent.com/openstack/releases/master/deliverables"
$CLONE_SERVERS = @{
    opendev = "https://opendev.org"
    github  = "https://github.com"
}

# ─────────────────────────────────────────────────────────────────────────────
# Funções
# ─────────────────────────────────────────────────────────────────────────────

function Write-Status {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor $Color
}

function Get-GithubHeaders {
    param([string]$Token)
    $h = @{ "User-Agent" = "OpenStack-Clone-Script/1.0"; "Accept" = "application/vnd.github.v3+json" }
    if ($Token) { $h["Authorization"] = "token $Token" }
    return $h
}

function Get-DeliverableList {
    param([string]$ReleaseName, [string]$Token)

    $url     = "$GITHUB_API/$ReleaseName"
    $headers = Get-GithubHeaders -Token $Token

    try {
        $resp = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 60
        return $resp | Where-Object { $_.name -like "*.yaml" -and $_.type -eq "file" }
    }
    catch {
        $status = $_.Exception.Response?.StatusCode
        if ($status -eq 404) {
            Write-Error "Release '$ReleaseName' não encontrada no repositório de releases."
            Write-Error "Verifique o codinome em: https://releases.openstack.org/"
        }
        elseif ($status -eq 403) {
            Write-Error "Rate limit da API do GitHub atingido. Use -GitHubToken <token> para aumentar o limite."
        }
        else {
            Write-Error "Falha ao acessar GitHub API: $_"
        }
        exit 1
    }
}

function ConvertFrom-DeliverableYaml {
    <#
    Extrai repositórios e última versão estável de um YAML de deliverable do OpenStack.
    Retorna: [PSCustomObject]@{ Repo; Version } (um por repositório)
    #>
    param([string]$Yaml, [string]$Filename)

    # Versões estáveis (excluir RC, alpha, beta)
    # Exemplos de pré-release: 31.0.0.0rc1  1.2.3a1  1.0.0b3  2.0.0.0b1
    $allVersions = [regex]::Matches($Yaml, '(?m)^\s*-\s+version:\s+(\S+)') |
                   ForEach-Object { $_.Groups[1].Value.Trim() }

    $stableVersions = @($allVersions |
                        Where-Object { $_ -notmatch 'rc\d*' -and $_ -notmatch '\d[ab]\d' })

    if ($stableVersions.Count -eq 0) {
        Write-Verbose "Sem versão estável em: $Filename"
        return @()
    }

    $latestVersion = $stableVersions[-1]

    # Repositórios referenciados nas releases
    # Formato YAML: "      - repo: openstack/nova"
    $repos = @([regex]::Matches($Yaml, '(?m)^\s+-?\s*repo:\s+(\S+)') |
               ForEach-Object { $_.Groups[1].Value.Trim() } |
               Sort-Object -Unique)

    if ($repos.Count -eq 0) {
        # Fallback: repository-settings section
        # Formato: "  openstack/nova: {}"
        $repos = @([regex]::Matches($Yaml, '(?m)^  ([a-z][a-z0-9_-]+/[a-z][a-z0-9._-]+):') |
                   ForEach-Object { $_.Groups[1].Value.Trim() } |
                   Sort-Object -Unique)
    }

    if ($repos.Count -eq 0) {
        Write-Verbose "Nenhum repositório encontrado em: $Filename"
        return @()
    }

    return $repos | ForEach-Object {
        [PSCustomObject]@{
            Repo    = $_
            Version = $latestVersion
        }
    }
}

function Invoke-GitClone {
    <#
    Clona um repositório e faz checkout na tag especificada.
    Retorna: PSCustomObject com Status (cloned | skipped | error)
    #>
    param(
        [string]$Repo,
        [string]$Tag,
        [string]$DestDir,
        [string]$CloneBaseUrl,
        [bool]  $UseShallow
    )

    $result = [PSCustomObject]@{
        Repo   = $Repo
        Tag    = $Tag
        Dest   = $DestDir
        Status = "pending"
        Error  = ""
    }

    # Já clonado → pular
    if (Test-Path (Join-Path $DestDir ".git")) {
        $result.Status = "skipped"
        return $result
    }

    $cloneUrl = "$CloneBaseUrl/$Repo"
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

    # Usar & (call operator) + splatting — lida corretamente com paths com espaços
    $gitArgs = [System.Collections.Generic.List[string]]@("clone", "--quiet")
    if ($UseShallow) { $gitArgs.Add("--depth"); $gitArgs.Add("1") }
    $gitArgs.Add("--branch"); $gitArgs.Add($Tag)
    $gitArgs.Add($cloneUrl);  $gitArgs.Add($DestDir)

    $output   = & git @gitArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $errMsg = ($output | Out-String).Trim() -replace "`n", " "
        if ((Get-ChildItem $DestDir -Force -ErrorAction SilentlyContinue |
             Measure-Object).Count -eq 0) {
            Remove-Item $DestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $result.Status = "error"
        $result.Error  = if ($errMsg) { $errMsg } else { "Exit code $exitCode" }
    }
    else {
        $result.Status = "cloned"
    }

    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# Início
# ─────────────────────────────────────────────────────────────────────────────

$banner = @"

  ╔═══════════════════════════════════════════════════╗
  ║        OpenStack Repository Cloner                ║
  ╠═══════════════════════════════════════════════════╣
  ║  Release      : $($Release.PadRight(33))║
  ║  Destino      : $($OutputDir.PadRight(33))║
  ║  Modo clone   : $($(if ($Shallow) { 'shallow (--depth 1 + --branch <tag>)' } else { 'completo (histórico inteiro)   ' }).PadRight(33))║
  ║  Servidor git : $($CloneServer.PadRight(33))║
  ║  Paralelismo  : $("$ThrottleLimit workers".PadRight(33))║
"@
if ($Filter) {
    $banner += "`n  ║  Filtro       : $($Filter.PadRight(33))║"
}
$banner += "`n  ╚═══════════════════════════════════════════════════╝`n"
Write-Host $banner -ForegroundColor Cyan

# 1. Verificar dependências
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git não encontrado no PATH. Instale o Git For Windows e tente novamente."
    exit 1
}

# 2. Criar diretório de saída
$resolvedOut = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
New-Item -ItemType Directory -Path $resolvedOut -Force | Out-Null

# 3. Listar deliverables via GitHub API
Write-Status "Buscando deliverables da release '$Release' via GitHub API..."
$yamlFiles = Get-DeliverableList -ReleaseName $Release -Token $GitHubToken
Write-Status "Encontrados $($yamlFiles.Count) arquivos de deliverable." "Green"

# 4. Baixar e parsear cada YAML (sequencial — são chamadas rápidas a raw.githubusercontent.com)
Write-Status "Analisando deliverables..."

$allItems   = [System.Collections.Generic.List[PSCustomObject]]::new()
$parseErros = 0
$i          = 0

foreach ($file in $yamlFiles) {
    $i++
    Write-Progress -Activity "Analisando deliverables ($i/$($yamlFiles.Count))" `
                   -Status $file.name `
                   -PercentComplete ([int](($i / $yamlFiles.Count) * 100))

    $rawUrl = "$GITHUB_RAW/$Release/$($file.name)"
    try {
        $yaml = (Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -TimeoutSec 30).Content
    }
    catch {
        Write-Warning "Falha ao baixar $($file.name): $_"
        $parseErros++
        continue
    }

    $entries = ConvertFrom-DeliverableYaml -Yaml $yaml -Filename $file.name
    foreach ($e in $entries) {
        if ($Filter -and $e.Repo -notmatch $Filter) { continue }
        $allItems.Add($e)
    }
}

Write-Progress -Activity "Analisando deliverables" -Completed

# Eliminar duplicatas (mesmo repo em múltiplos deliverables — pouco comum mas acontece)
$allItems = [System.Collections.Generic.List[PSCustomObject]](
    $allItems | Sort-Object Repo -Unique
)

Write-Status "Repositórios identificados: $($allItems.Count)  (falhas de parsing: $parseErros)" "Green"
if ($allItems.Count -eq 0) {
    Write-Warning "Nenhum repositório encontrado. Verifique o release e o filtro."
    exit 0
}

# 5. Clonar em paralelo
Write-Host ""
Write-Status "Iniciando clones (ThrottleLimit=$ThrottleLimit)..." "Yellow"
Write-Host ""

$cloneBase = $CLONE_SERVERS[$CloneServer]
$useShallow = $Shallow

$cloneResults = $allItems | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {

    # Capturar variáveis do escopo externo
    $item      = $_
    $baseDir   = $using:resolvedOut
    $shallow   = $using:useShallow
    $cloneBase = $using:cloneBase

    # ── Funções internas (ForEach-Object -Parallel não herda funções) ──────

    function Clone-Repo {
        param($Repo, $Tag, $DestDir, $CloneBaseUrl, $UseShallow)

        $result = [PSCustomObject]@{
            Repo   = $Repo
            Tag    = $Tag
            Dest   = $DestDir
            Status = "pending"
            Error  = ""
        }

        if (Test-Path (Join-Path $DestDir ".git")) {
            $result.Status = "skipped"; return $result
        }

        $cloneUrl = "$CloneBaseUrl/$Repo"
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

        $gitArgs = [System.Collections.Generic.List[string]]@("clone", "--quiet")
        if ($UseShallow) { $gitArgs.Add("--depth"); $gitArgs.Add("1") }
        $gitArgs.Add("--branch"); $gitArgs.Add($Tag)
        $gitArgs.Add($cloneUrl);  $gitArgs.Add($DestDir)

        $output   = & git @gitArgs 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $errMsg = ($output | Out-String).Trim() -replace "`n", " "
            if ((Get-ChildItem $DestDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
                Remove-Item $DestDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            $result.Status = "error"
            $result.Error  = if ($errMsg) { $errMsg } else { "Exit $exitCode" }
        }
        else {
            $result.Status = "cloned"
        }

        return $result
    }

    # ── Calcular caminho de destino ──────────────────────────────────────

    # Ex: openstack/nova  →  <OutputDir>\openstack\nova
    $parts    = $item.Repo -split '/', 2
    $ns       = $parts[0]
    $repoName = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
    $destDir  = Join-Path $baseDir (Join-Path $ns $repoName)

    $r = Clone-Repo -Repo $item.Repo -Tag $item.Version -DestDir $destDir `
                    -CloneBaseUrl $cloneBase -UseShallow $shallow

    # Exibir linha de progresso (thread-safe com Write-Host)
    $icon  = switch ($r.Status) { "cloned" { "+" } "skipped" { "~" } "error" { "!" } default { "?" } }
    $color = switch ($r.Status) { "cloned" { "Green" } "skipped" { "Yellow" } "error" { "Red" } default { "Gray" } }
    Write-Host "  [$icon] $($r.Repo)  @$($r.Tag)" -ForegroundColor $color
    if ($r.Status -eq "error") {
        Write-Host "      ERR: $($r.Error)" -ForegroundColor DarkRed
    }

    $r   # retornar resultado para coleção
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
        Write-Host "    $($_.Repo)  @$($_.Tag)" -ForegroundColor DarkRed
        Write-Host "      $($_.Error)" -ForegroundColor DarkRed
    }
    Write-Host ""
    Write-Host "  Dica: execute o script novamente — repositórios já clonados serão pulados." -ForegroundColor Yellow
}

# Salvar relatório CSV
$csvPath = Join-Path $resolvedOut "_summary.csv"
$cloneResults |
    Select-Object Repo, Tag, Status, Dest, Error |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Status "Relatório salvo : $csvPath" "Cyan"
Write-Status "Repositórios em : $resolvedOut" "Cyan"
Write-Host ""
