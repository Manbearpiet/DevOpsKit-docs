﻿function Pre_requisites {
  <#
  .SYNOPSIS
  This command would check pre requisities modules.
  .DESCRIPTION
  This command would check pre requisities modules to perform clean-up.
#>

  Write-Host "Required modules are: Az.Resources, Az.Accounts, AzureAD" -ForegroundColor Cyan
  Write-Host "Checking for required modules..."
  $availableModules = $(Get-Module -ListAvailable Az.Resources, Az.Accounts, AzureAD)
  
  # Checking if 'Az.Accounts' module is available or not.
  if ($availableModules.Name -notcontains 'Az.Accounts') {
    Write-Host "Installing module Az.Accounts..." -ForegroundColor Yellow
    Install-Module -Name Az.Accounts -Scope CurrentUser -Repository 'PSGallery'
  }
  else {
    Write-Host "Az.Accounts module is available." -ForegroundColor Green
  }

  # Checking if 'Az.Resources' module is available or not.
  if ($availableModules.Name -notcontains 'Az.Resources') {
    Write-Host "Installing module Az.Resources..." -ForegroundColor Yellow
    Install-Module -Name Az.Resources -Scope CurrentUser -Repository 'PSGallery'
  }
  else {
    Write-Host "Az.Resources module is available." -ForegroundColor Green
  }
  # Checking if 'AzureAD' module is available or not.
  if ($availableModules.Name -notcontains 'AzureAD') {
    Write-Host "Installing module AzureAD..." -ForegroundColor Yellow
    Install-Module -Name AzureAD -Scope CurrentUser -Repository 'PSGallery'
  }
  else {
    Write-Host "AzureAD module is available." -ForegroundColor Green
  }
}
function Read_UserChoice {
  $userSelection = ""
  while ($userSelection -ne 'Y' -and $userSelection -ne 'N') {
    $userSelection = Read-Host "User choice"
    if (-not [string]::IsNullOrWhiteSpace($userSelection)) {
      $userSelection = $userSelection.Trim();
    }
  }

  return $userSelection;
}
function Delete_AADApplication {
  param ($AadAppId, $force)

  Write-Host "Deleting AAD application of AzSK SPN $($AadAppId).Do You want to continue?`n[Y]: Yes`n[N]: No"
  if($force){
    $userChoice ='Y'
  }
  else {
    Write-Host "`nPlease confirm deletion of SPN $($AadAppId).: `n[Y]: Yes`n[N]: No" -ForegroundColor Cyan 
    $userChoice = Read_UserChoice 
  }
  if ($userChoice -eq 'Y') {
    try {
      $success = Remove-AzADApplication -ApplicationId $AadAppId -Force
      # Added this check as remove-azadapplication not returning success true/false properly
      $appStillExist = Get-AzADApplication -ApplicationId $AadAppId -ErrorAction SilentlyContinue
      if ($appStillExist) {
        throw;
      }
      Write-Host "Successfully deleted AAD application of AzSK SPN $($AadAppId)" -ForegroundColor Green
    }
    catch {
      Write-Host "Error while deleting AAD application of AzSK SPN." -ForegroundColor DarkYellow
    }

  }
}
Function Remove-AzSKSPN {
  <#
    .SYNOPSIS
    This command will remove AzSK/AzSDK deployed SPNs from AAD.Please make sure to confirm these SPNs are not used for other purpose prior to running this script.
    .DESCRIPTION
    This command will remove AzSK/AzSDK deployed SPNs from AAD.Please make sure to confirm these SPNs are not used for other purpose prior to running this script.
    .PARAMETER Force
        Use this switch to avoid user confimration before deletion of SPNs.
    #>
  param (
    [switch]
    $force
  )

  try {
    Write-Host "Checking for pre-requisites..."
    Pre_requisites
    Write-Host "------------------------------------------------------"     
  }
  catch {
    Write-Host "Error occured while checking pre-requisites. ErrorMessage [$($_)]" -ForegroundColor Red    
    break
  }
  Write-Host "Connecting to AzureAD..."
  Connect-AzureAD
  Write-Host "Connected to AzureAD" -ForegroundColor Green
  
  # Connect to AzAccount
  $isContextSet = Get-AzContext
  if ([string]::IsNullOrEmpty($isContextSet)) {
    Write-Host "Connecting to AzAccount..."
    Connect-AzAccount
    Write-Host "Connected to AzAccount" -ForegroundColor Green
  }
  
  #List SPNs
  $objectId = (Get-AzureADUser  -Filter "UserPrincipalName eq '$($(Get-AzContext).Account)'").ObjectId
  $spnList = Get-AzureADUserOwnedObject -ObjectId $objectId | Where-Object { ($_.ObjectType -eq "ServicePrincipal") -and (($_.DisplayName -like "AzSK_CA_SPN*") -or ($_.DisplayName -like "AzSDK_CA_SPN*") ) } 
  Write-Host("`nList of SPNs for which current logged in user is Owner`n")
  $spnList | Select-Object "DisplayName", "ObjectId", "AppId" | Format-Table
  foreach ($spn in $spnList) {
    Delete_AADApplication($spn.AppId, $force)
  } 
}

