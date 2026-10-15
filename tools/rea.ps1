# REA wrapper - sets the Ghidra/JDK environment for this project.
# Usage (from the project root):
#   & .\tools\rea.ps1 analyze "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\Insaniquarium.exe" --provider ghidra --json --snapshot docs\analysis\snapshots\insaniquarium.json
# All arguments are forwarded to `rea` unchanged.

$env:GHIDRA_INSTALL_DIR = "C:\tools\ghidra_12.1.4_PUBLIC"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
$env:REA_ANALYSIS_PROVIDER = "ghidra"

& rea @args
exit $LASTEXITCODE
