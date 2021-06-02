# Список контролеров домена
$AD_ControllersName = @("srv-01", "srv-02")

for ( $index = 0; $index -lt $AD_ControllersName.count; $index++ ) {
  $s = New-PSSession $AD_ControllersName[$index]
  if ($s) {
    Invoke-Command -Session $s -ScriptBlock {
      param($ComputerName, $UserName) 
      $ADComp = Get-ADComputer -Identity $ComputerName
      if ($ADComp) {
        $curusr_cn = (get-aduser $env:UserName -properties *).DistinguishedName
        $ADComp.description = $UserName
        $ADComp.ManagedBy = $curusr_cn
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