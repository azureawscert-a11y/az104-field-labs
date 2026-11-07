// Lab 05: one small Linux VM with no public IP, in its own VNet and NSG.
// Read it top to bottom: parameters, variables, resources, outputs.

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('VM name')
param vmName string = 'vm-web01'

@description('VM size. B2ats_v2 (Bsv2 series) is a cheap burstable size for labs. deploy.sh passes the size that works in your subscription.')
param vmSize string = 'Standard_B2ats_v2'

@description('Admin user name for SSH')
param adminUsername string = 'azureuser'

@description('Your SSH public key (contents of ~/.ssh/id_rsa.pub or id_ed25519.pub)')
@secure()
param adminPublicKey string

@description('Add a 16 GiB data disk at LUN 0 (step 5 of deploy.sh turns this on)')
param addDataDisk bool = false

@description('Tags applied to every resource')
param tags object = {
  lab: '05'
  env: 'dev'
}

var vnetName = 'vnet-lab05'
var subnetName = 'snet-web'
var nsgName = 'nsg-web'
var nicName = '${vmName}-nic'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-http-from-vnet'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.50.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.50.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
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
      diskControllerType: contains(vmSize, '_v6') ? 'NVMe' : 'SCSI'
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
          storageAccountType: 'Standard_LRS'
        }
      }
      // Condition inside an expression: one disk when addDataDisk is true, none otherwise
      dataDisks: addDataDisk ? [
        {
          lun: 0
          name: '${vmName}-data0'
          createOption: 'Empty'
          diskSizeGB: 16
          deleteOption: 'Delete'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ] : []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

output vmId string = vm.id
output dataDiskCount int = length(vm.properties.storageProfile.dataDisks)
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
