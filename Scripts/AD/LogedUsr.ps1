$ErrorActionPreference = "SilentlyContinue"
Add-Type -assembly System.Windows.Forms
 
$main_form = New-Object System.Windows.Forms.Form
$main_form.Text ='Кто работает за компьютером'
$main_form.Width = 500
$main_form.Height = 300
$main_form.AutoScale = $true
$main_form.StartPosition = "CenterScreen"

$ListView = New-Object System.Windows.Forms.ListView
$listView.Columns.Add('Компьютер')
$listView.Columns.Add('Имя пользователя')
$listView.Columns.Add('Дата входа')
$listView.Columns.Add('Дата выхода')

$ListView.Location = New-Object System.Drawing.Point(3,3)
$ListView.Width = $main_form.ClientSize.Width - 6
$ListView.Height = $main_form.ClientSize.Height - 35

$ListView.AutoSize = $true
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
$Button_Refresh.Text = "Обновить"
$Button_Refresh.Location = New-Object System.Drawing.Point(($Main_Form.ClientSize.Width - 80), ($Main_Form.ClientSize.Height - 30))
$Button_Refresh.AutoSize = $false
$Button_Refresh.Anchor = 'Bottom,Right'
$Main_Form.Controls.add($Button_Refresh)

function Update_Data {
  $ListView.BeginUpdate()
  $ListView.Items.Clear()
  
  $searcher = ([adsisearcher]"(objectCategory=computer)")
  $searcher.searchRoot = [adsi]"LDAP://OU=Workstations,OU=DSK_Computers,DC=corp,DC=dskvrn,DC=ru"

  foreach($item1 in ($searcher.findall())) {
    $item = [ADSI]$item1.Path
    
    if (($item.lastLogon.value -inotlike 0) -and ($item.lastLogon.value -inotlike "")) {
      $lastLogon = ([datetime]::FromFileTime($item.ConvertLargeIntegerToInt64($item.lastLogon.value))).ToString('dd.MM.yyyy HH:mm:ss')
    } else {
      $lastLogon = ""
    }

    if (($item.lastLogoff -inotlike 0) -and ($item.lastLogoff -inotlike "")) {
      $lastLogoff = ([datetime]::FromFileTime($item.ConvertLargeIntegerToInt64($item.lastLogoff.value))).ToString('dd.MM.yyyy HH:mm:ss')
    } else {
      $lastLogoff = ""
    }

    if ($item.Description -inotlike "") {
      if ($item.Description.Chars(0) -eq "[") {   
        $UserName   = $item.Description.Value.Substring(1,$item.Description.Value.IndexOf("]") - 1)

        $lastLogoff = $item.Description.Value.Substring($item.Description.Value.IndexOf("]") + 1, ($item.Description.Value.Length - $item.Description.Value.IndexOf("]") - 1))
      } else {
        $UserName   = $item.Description.Value
        $lastLogoff = ""
      }
    } else {
      $UserName = ""
      $lastLogoff = ""
    }

    $ListViewItem = New-Object System.Windows.Forms.ListViewItem($item.Name)  
    $ListViewItem.SubItems.Add($UserName)
    $ListViewItem.SubItems.Add($lastLogon)
    $ListViewItem.SubItems.Add($lastLogoff)

    $ListView.Items.Add($ListViewItem)
  }

  $listView.AutoResizeColumns(1)
  $listView.Refresh()
  $ListView.EndUpdate()
}

$Button_Refresh.Add_Click( {Update_Data} )
$main_form.Add_Shown( {Update_Data} )
$main_form.ShowDialog() | Out-Null