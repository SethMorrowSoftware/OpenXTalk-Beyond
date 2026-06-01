$f = 'C:\Users\user\Documents\GitHub\livecode\build-win-x86_64\livecode\engine\kernel-development.vcxproj'
$lines = [System.IO.File]::ReadAllLines($f)
$out = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
    $out.Add($line)
    if ($line -match 'internal_development\.cpp') {
        $out.Add('    <ClCompile Include="..\..\..\engine\src\respring.cpp"/>')
    }
}
[System.IO.File]::WriteAllLines($f, $out.ToArray())
Write-Host "Done - respring.cpp added to vcxproj"
