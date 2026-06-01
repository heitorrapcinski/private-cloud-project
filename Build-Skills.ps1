<#
.SYNOPSIS
    Empacota todos os skills da pasta skills\ em arquivos .skill prontos para instalação.

.DESCRIPTION
    Percorre cada subdiretório de skills\ que contenha um SKILL.md,
    chama o package_skill.py do skill-creator e gera o .skill correspondente
    em dist\skills\.

.PARAMETER SkillFilter
    Opcional. Empacota apenas o skill cujo nome case com esse valor.
    Ex: .\Build-Skills.ps1 -SkillFilter openstack-api

.EXAMPLE
    .\Build-Skills.ps1                        # empacota tudo
    .\Build-Skills.ps1 -SkillFilter openstack-dev
#>
[CmdletBinding()]
param(
    [string]$SkillFilter = ""
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

# ── Caminhos ────────────────────────────────────────────────────────────────

$ProjectRoot    = $PSScriptRoot
$SkillsDir      = Join-Path $ProjectRoot "skills"
$DistDir        = Join-Path $ProjectRoot "dist\skills"

# Localiza o package_skill.py dentro do skill-creator instalado no Claude
$SkillCreatorDir = Get-ChildItem `
    "$env:APPDATA\Claude\local-agent-mode-sessions\skills-plugin" `
    -Recurse -Filter "package_skill.py" -ErrorAction SilentlyContinue |
    Select-Object -First 1 |
    ForEach-Object { $_.Directory.Parent.FullName }  # sobe de scripts\ para skill-creator\

if (-not $SkillCreatorDir) {
    Write-Error "skill-creator não encontrado em AppData. Instale o skill-creator no Claude primeiro."
    exit 1
}

# ── Build ────────────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

$skills = Get-ChildItem $SkillsDir -Directory |
          Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") } |
          Where-Object { -not $SkillFilter -or $_.Name -like "*$SkillFilter*" }

if ($skills.Count -eq 0) {
    Write-Warning "Nenhum skill encontrado em '$SkillsDir'$(if ($SkillFilter) { " com filtro '$SkillFilter'" })."
    exit 0
}

Write-Host ""
Write-Host "  Empacotando $($skills.Count) skill(s) → dist\skills\" -ForegroundColor Cyan
Write-Host ""

$ok = 0; $fail = 0

Push-Location $SkillCreatorDir
foreach ($skill in $skills) {
    $output = python -m scripts.package_skill $skill.FullName $DistDir 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] $($skill.Name).skill" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "  [!] $($skill.Name) — ERRO:" -ForegroundColor Red
        Write-Host "      $output" -ForegroundColor DarkRed
        $fail++
    }
}
Pop-Location

Write-Host ""
Write-Host "  Gerados : $ok   Erros : $fail" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
Write-Host "  Pasta   : $DistDir" -ForegroundColor Cyan
Write-Host ""
