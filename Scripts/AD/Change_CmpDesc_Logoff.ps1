# Список контролеров домена
$AD_ControllersName = @("srv-01", "srv-02")

for ( $index = 0; $index -lt $AD_ControllersName.count; $index++ ) {
  $s = New-PSSession $AD_ControllersName[$index]
  if ($s) {
    Invoke-Command -Session $s -ScriptBlock {
      param($ComputerName, $UserName) 
      $ADComp = Get-ADComputer -Identity $ComputerName
      if ($ADComp) {
        $tdate = (Get-Date).ToString()
        $ADComp.description = "[$UserName] $tdate"
        Set-ADComputer -Instance $ADComp
      } else {
        $ADComp = "_"
      }
    } -ArgumentList $env:ComputerName, $env:UserName
    $ADComp = Invoke-Command -Session $s {$ADComp}
    if ($ADComp -ne "_") {
      break
    }
    Remove-PSSession $s
  }
}