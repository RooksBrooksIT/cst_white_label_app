# PowerShell script to apply SafeArea to all screen files
$screenDir = "d:\Rooks-projects\Flutter\CST-whitelabel app\cst_white_label_app\lib\screens"

# Get all dart files in screens directory
Get-ChildItem -Path $screenDir -Filter "*.dart" | ForEach-Object {
    $filePath = $_.FullName
    $fileName = $_.Name
    Write-Host "Checking file: $fileName"
    
    $content = Get-Content -Path $filePath -Raw -Encoding UTF8
    
    # Check if the file already contains SafeArea
    if ($content -match 'SafeArea') {
        Write-Host "  $fileName already has SafeArea - skipping"
        return
    }
    
    # Check if the file contains GlassScaffold or Scaffold
    if ($content -match 'GlassScaffold|Scaffold') {
        Write-Host "  Processing: $fileName"
        
        # Try to wrap the 'body: ' content with SafeArea(bottom: true, ... )
        # Use a regex to find the body section
        # Regex pattern to match body: [something], (handle single/multi-line)
        # This is a simple approach - look for body: followed by content up to the next , that is at the same nesting level
        # For simplicity, we'll use a simple replacement that matches most common patterns
        
        $newContent = $content -replace '(body:)(\s*)([^\n;]+(?:\n[^,;]*)*)', '$1$2SafeArea(bottom: true, child: $3)'
        
        # If the replacement didn't change anything, try another approach
        if ($newContent -eq $content) {
            Write-Host "  Could not automatically update $fileName - please check manually"
        } else {
            Set-Content -Path $filePath -Value $newContent -Encoding UTF8
            Write-Host "  Successfully updated $fileName"
        }
    } else {
        Write-Host "  $fileName does not contain GlassScaffold/Scaffold - skipping"
    }
}

Write-Host "All files processed!"
