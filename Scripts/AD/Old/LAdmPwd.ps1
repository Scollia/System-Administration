$ErrorActionPreference = "SilentlyContinue"
Add-Type -assembly System.Windows.Forms
$username = "NewLocalAdmin"
 
$main_form = New-Object System.Windows.Forms.Form
$main_form.Text ='—писок локальных администраторов'
$main_form.Width = 500
$main_form.Height = 300
#$main_form.AutoSize = $true
$main_form.AutoScale = $true
$main_form.StartPosition = "CenterScreen"

$ListView = New-Object System.Windows.Forms.ListView
$listView.Columns.Add(' омпьютер')
$listView.Columns.Add('»м€ администратора')
$listView.Columns.Add('ѕароль')
$listView.Columns.Add('—рок действи€ парол€')

$ListView.Location = New-Object System.Drawing.Point(3,3)
$ListView.Width = $main_form.ClientSize.Width - 6
$ListView.Height = $main_form.ClientSize.Height - 35

$ListView.AutoSize = $true
#$ListView.Margin.All = $true
$ListView.Anchor = 'Top,Left,Bottom,Right'
$listView.View = [System.Windows.Forms.View]::Details
$listView.LabelEdit = $false
$listView.HideSelection = $false
$listView.FullRowSelect = $true
$listView.MultiSelect=$false
$listView.GridLines = $true
$listView.AllowColumnReorder = $true
$listView.Sorting = [System.Windows.Forms.SortOrder]::Ascending

$listView.AutoResizeColumns(1)
$main_form.Controls.add($ListView)

$Button_Refresh = New-Object System.Windows.Forms.Button
$Button_Refresh.Text = "ќбновить"
$Button_Refresh.Location = New-Object System.Drawing.Point(($Main_Form.ClientSize.Width - 80), ($Main_Form.ClientSize.Height - 30))
$Button_Refresh.AutoSize = $false
$Button_Refresh.Anchor = 'Bottom,Right'
$Main_Form.Controls.add($Button_Refresh)

function Update_Data {
  $ListView.BeginUpdate()
  $ListView.Items.Clear()

  #foreach($item in (Invoke-Command -ComputerName srv-dc-01 -ScriptBlock {Get-ADComputer -Filter {ms-Mcs-AdmPwd -like "*"} -SearchBase УOU=Workstations,OU=DSK_Computers,DC=corp,DC=dskvrn,DC=ruФ | Get-AdmPwdPassword -ComputerName {$_.Name}})){
  foreach($item in (Invoke-Command -ComputerName srv-dc-01 -ScriptBlock {Get-ADComputer -Filter "*" -SearchBase УOU=Workstations,OU=DSK_Computers,DC=corp,DC=dskvrn,DC=ruФ | Get-AdmPwdPassword -ComputerName {$_.Name}})) {
    $ListViewItem = New-Object System.Windows.Forms.ListViewItem($item.ComputerName)
#    if (Invoke-Command -ComputerName $item.ComputerName -ScriptBlock {Get-LocalUser | Where-Object {$_.Name -eq "wsituser"}}) {
    if ($item.Password) {
      $ListViewItem.SubItems.Add($username)
      $ListViewItem.SubItems.Add($item.Password)
      $ListViewItem.SubItems.Add($item.ExpirationTimestamp.ToString('dd.MM.yyyy HH:mm:ss'))
write-host ($item.ComputerName + " " + $item.Password)
    } else {
      $ListViewItem.SubItems.Add("")
      $ListViewItem.SubItems.Add("")
      $ListViewItem.SubItems.Add("")
    }
    $ListView.Items.Add($ListViewItem)  
  }

  $listView.AutoResizeColumns(1)
  $listView.Refresh()
  $ListView.EndUpdate()
}

$Button_Refresh.Add_Click( {Update_Data} )
$main_form.Add_Shown( {Update_Data} )

$main_form.ShowDialog() | Out-Null