// Capstone: a mini landing zone for a small company (Northwind Clinic, fictional).
// Hub-spoke network, NSG, private storage with private endpoint + DNS, one app VM, Log Analytics, action group, CPU alert.
// Governance (tags policy, RBAC, lock) and backup are applied by deploy.sh with the CLI.

param location string = resourceGroup().location

@description('SSH public key for the app VM')
@secure()
param adminPublicKey string

@description('Admin user name for the app VM')
param adminUsername string = 'azureuser'

@description('Storage redundancy. ZRS needs a region with availability zones; deploy.sh picks LRS where there are none.')
param storageSku string = 'Standard_ZRS'

@description('VM size for vm-app01. deploy.sh passes the size that works in your subscription.')
param vmSize string = 'Standard_B2ats_v2'

@description('Email for alerts')
param alertEmail string

@description('Short unique suffix for globally unique names')
param suffix string = substring(uniqueString(resourceGroup().id), 0, 6)

param tags object = {
  CostCenter: 'IT-100'
  env: 'prod'
  owner: 'cloud-ops'
}

var storageName = 'stnwclinic${suffix}'
var blobZone = 'privatelink.blob.${environment().suffixes.storage}'

// ---------- Network ----------
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-snet-app'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-ssh-from-hub'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.0.0/16'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-https-from-vnet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'deny-all-other-inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnetHub 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-hub'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-shared'
        properties: {
          addressPrefix: '10.10.1.0/24'
        }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: '10.10.2.0/24'
        }
      }
    ]
  }
}

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-spoke-app'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
    ]
  }
}

resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnetHub
  name: 'hub-to-spoke-app'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSpoke.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnetSpoke
  name: 'spoke-app-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: vnetHub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

// ---------- Private storage ----------
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: 14
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
  }
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: blobZone
  location: 'global'
  tags: tags
}

resource dnsLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZone
  name: 'link-hub'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetHub.id
    }
  }
}

resource dnsLinkSpoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dnsZone
  name: 'link-spoke-app'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetSpoke.id
    }
  }
}

resource peBlob 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${storageName}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: vnetHub.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: 'conn-blob'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource peDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: peBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: dnsZone.id
        }
      }
    ]
  }
}

// ---------- App VM ----------
resource nicApp 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'vm-app01-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetSpoke.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource vmApp 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-app01'
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm-app01'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      // v6 sizes only support NVMe disks; older sizes use SCSI
      diskControllerType: (contains(toLower(vmSize), '_v6') || contains(toLower(vmSize), '_v7')) ? 'NVMe' : 'SCSI'
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicApp.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

// ---------- Monitoring ----------
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-nwclinic'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource diagBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-blob-to-law'
  scope: blobService
  properties: {
    workspaceId: law.id
    logs: [
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

resource ag 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-cloud-ops'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'cloudops'
    enabled: true
    emailReceivers: [
      {
        name: 'ops-email'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource cpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-vm-app01-cpu'
  location: 'global'
  tags: tags
  properties: {
    description: 'CPU above 80% for 5 minutes on vm-app01'
    severity: 2
    enabled: true
    scopes: [
      vmApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: 'cpu-high'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: ag.id
      }
    ]
  }
}

output storageAccountName string = storage.name
output vmName string = vmApp.name
output workspaceId string = law.id
