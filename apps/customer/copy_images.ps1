Copy-Item "C:\Users\axero\.gemini\antigravity\brain\3bae8c87-1f00-49ed-a673-ee1d4545c1ed\delivery_card_1775670002242.png" "c:\Project TakEsep\TakEsep\apps\customer\assets\images\delivery.png" -Force
Copy-Item "C:\Users\axero\.gemini\antigravity\brain\3bae8c87-1f00-49ed-a673-ee1d4545c1ed\services_card_1775670017744.png" "c:\Project TakEsep\TakEsep\apps\customer\assets\images\services.png" -Force
Write-Output "Files copied successfully"
Get-ChildItem "c:\Project TakEsep\TakEsep\apps\customer\assets\images\"
