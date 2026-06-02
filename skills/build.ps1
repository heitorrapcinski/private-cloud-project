<#
.SYNOPSIS
    Empacota todos os skills em arquivos .skill (ZIP) prontos para instalação.

.DESCRIPTION
    Percorre cada subdiretório de domínio em skills\ (openstack\, kvm\, …) que
    contenha pastas com SKILL.md, valida o frontmatter YAML e gera um <nome>.skill
    (arquivo ZIP) em skills\dist\.
    Não depende de ferramentas externas — usa apenas Python stdlib (zipfile, re).

.PARAMETER Domain
    Opcional. Limita o build a um domínio específico (nome da subpasta).
    Ex: .\build.ps1 -Domain kvm
    Padrão: todos os domínios.

.PARAMETER Filter
    Opcional. Empacota apenas o skill cujo nome contenha esse valor.
    Ex: .\build.ps1 -Filter ops

.PARAMETER Clean
    Apaga o conteúdo de dist\ antes de empacotar.

.EXAMPLE
    .\build.ps1                          # empacota todos os skills de todos os domínios
    .\build.ps1 -Domain kvm              # apenas skills KVM
    .\build.ps1 -Domain openstack -Filter ops
    .\build.ps1 -Clean                   # limpa dist\ e reempacota tudo
#>
[CmdletBinding()]
param(
    [string]$Domain = "",
    [string]$Filter = "",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"

# ── Caminhos ────────────────────────────────────────────────────────────────
$SkillsBase = $PSScriptRoot           # skills\
$DistDir    = Join-Path $PSScriptRoot "dist"

# ── Python inline packager ───────────────────────────────────────────────────
# Cria um .skill (ZIP) sem depender do skill-creator instalado no Claude.
$PackagerScript = @'
import sys, re, zipfile, pathlib

skill_dir = pathlib.Path(sys.argv[1])
dist_dir  = pathlib.Path(sys.argv[2])
dist_dir.mkdir(parents=True, exist_ok=True)

skill_md = skill_dir / "SKILL.md"
if not skill_md.exists():
    print(f"  ERRO: SKILL.md nao encontrado em {skill_dir}")
    sys.exit(1)

# Validate frontmatter
content = skill_md.read_text(encoding="utf-8")
m = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
if not m:
    print(f"  ERRO: frontmatter YAML ausente ou malformado em {skill_md}")
    sys.exit(1)

front = m.group(1)
if not re.search(r"^name\s*:", front, re.MULTILINE):
    print(f"  ERRO: campo 'name' ausente no frontmatter")
    sys.exit(1)
if not re.search(r"^description\s*:", front, re.MULTILINE):
    print(f"  ERRO: campo 'description' ausente no frontmatter")
    sys.exit(1)

# Package: ZIP with skill_name/SKILL.md (+ any extra files)
skill_name  = skill_dir.name
output_file = dist_dir / f"{skill_name}.skill"

EXCLUDE_DIRS  = {"__pycache__", "node_modules", "evals", ".git"}
EXCLUDE_FILES = {".DS_Store"}
EXCLUDE_GLOBS = ("*.pyc",)

import fnmatch

with zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as zf:
    for fpath in sorted(skill_dir.rglob("*")):
        if not fpath.is_file():
            continue
        rel = fpath.relative_to(skill_dir.parent)
        parts = rel.parts
        if any(p in EXCLUDE_DIRS for p in parts):
            continue
        if fpath.name in EXCLUDE_FILES:
            continue
        if any(fnmatch.fnmatch(fpath.name, g) for g in EXCLUDE_GLOBS):
            continue
        zf.write(fpath, rel)

print(f"  OK: {output_file.name}  ({output_file.stat().st_size} bytes)")
sys.exit(0)
'@

# ── Sanity checks ────────────────────────────────────────────────────────────
if (-not (Test-Path $SkillsBase)) {
    Write-Error "Pasta de skills nao encontrada: $SkillsBase"
    exit 1
}

try { python --version | Out-Null } catch {
    Write-Error "Python nao encontrado no PATH. Instale Python 3.8+ para usar este script."
    exit 1
}

# ── Limpar dist\ se solicitado ───────────────────────────────────────────────
if ($Clean -and (Test-Path $DistDir)) {
    Write-Host "  Limpando dist\..." -ForegroundColor DarkGray
    Remove-Item "$DistDir\*.skill" -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

# ── Descobrir domínios e skills ──────────────────────────────────────────────
# Domínios são subpastas diretas de skills\ que NÃO são "dist"
$domains = Get-ChildItem $SkillsBase -Directory |
           Where-Object { $_.Name -ne "dist" } |
           Where-Object { -not $Domain -or $_.Name -eq $Domain }

$skills = $domains | ForEach-Object {
    Get-ChildItem $_.FullName -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") }
} | Where-Object { -not $Filter -or $_.Name -like "*$Filter*" }

if (-not $skills -or @($skills).Count -eq 0) {
    $hint = @(
        if ($Domain) { " domínio '$Domain'" }
        if ($Filter) { " filtro '$Filter'" }
    ) -join ","
    Write-Warning "Nenhum skill encontrado$hint."
    exit 0
}

# ── Empacotar ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Empacotando $(@($skills).Count) skill(s) -> dist\" -ForegroundColor Cyan
Write-Host ""

$ok = 0; $fail = 0

foreach ($skill in @($skills)) {
    Write-Host "  [ $($skill.Name) ]" -ForegroundColor DarkCyan -NoNewline
    Write-Host ""

    $tmp = New-TemporaryFile
    try {
        $PackagerScript | python - $skill.FullName $DistDir 2>&1 | ForEach-Object {
            if ($_ -match "^  ERRO") {
                Write-Host "    $_" -ForegroundColor Red
            } elseif ($_ -match "^  OK") {
                Write-Host "    $_" -ForegroundColor Green
            } else {
                Write-Host "    $_" -ForegroundColor DarkGray
            }
        }

        if ($LASTEXITCODE -eq 0) { $ok++ } else { $fail++ }
    } catch {
        Write-Host "    EXCECAO: $_" -ForegroundColor Red
        $fail++
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

# ── Resumo ────────────────────────────────────────────────────────────────────
Write-Host ""
$color = if ($fail -eq 0) { "Green" } else { "Yellow" }
Write-Host "  Gerados : $ok   Erros : $fail" -ForegroundColor $color
Write-Host "  Saida   : $DistDir" -ForegroundColor Cyan
Write-Host ""

exit $(if ($fail -gt 0) { 1 } else { 0 })
