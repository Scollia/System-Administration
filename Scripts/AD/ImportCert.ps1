<#
PowerShell может получить доступ к логическим хранилищам Windows с помощью PSDrive-объекта "Cert:\"

My			Личное
Root			Доверенные корневые центры сертификации
Trust			Доверенные отношения в предприятии
CA			Промежуточные центры сертификации
UserDS			Объект пользователя Active Directory
TrustedPublisher	Доверенные издатели
AuthRoot                Third-Party Root Certification Authorities
TrustedPeople           Доверенные лица
ClientAuthIssuer	Поставщики сертификатов проверки подлинности клиентов
addressbook		Другие пользователи
REQUEST                 Запросы заявок на сертификат
SmartCardRoot
Disallowed
ACRS

Local NonRemovable Certificates
Remote Desktop 		Remote Desktop
#>

Get-ChildItem -Path \\corp.dskvrn.ru\sharedpo\Certificates | Foreach-Object {
  $logicalstorage = $_.Name
  Get-ChildItem -Path \\corp.dskvrn.ru\sharedpo\Certificates\$logicalstorage\*.cer | Foreach-Object {
    Import-Certificate -FilePath $_.FullName -CertStoreLocation Cert:\CurrentUser\$logicalstorage
  }
}

# $pfxPassword = "ComplexPassword!" | ConvertTo-SecureString -AsPlainText -Force
# Import-PfxCertificate -Exportable -Password $pfxPassword -CertStoreLocation 'Cert:\CurrentUser\My' -FilePath $env:USERPROFILE\Desktop\certificate.pfx