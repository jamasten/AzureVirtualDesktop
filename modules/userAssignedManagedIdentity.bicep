param DiskEncryption bool
param DrainMode bool
param Fslogix bool
param FslogixStorage string
param Location string
param ResourceGroupStorage string
param Timestamp string
param UserAssignedIdentityName string
param VirtualNetworkResourceGroupName string

var DiskEncryptionRoleAssignment = DiskEncryption ? [
  {
    roleDefinitionId: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603' // Key Vault Crypto Officer (Bitlocker key)
    scope: resourceGroup().name
  }
] : []
var DrainModeRoleAssignment = DrainMode ? [
  {
    roleDefinitionId: '2ad6aaab-ead9-4eaa-8ac5-da422f562408' // Desktop Virtualization Session Host Operator (Drain Mode)
    scope: resourceGroup().name
  }
] : []
var FSLogixNtfsRoleAssignments = Fslogix ? [
  {
    roleDefinitionId: 'a959dbd1-f747-45e3-8ba6-dd80f235f97c' // Desktop Virtualization Virtual Machine Contributor (NTFS Permissions - Remove management virtual machine)
    scope: resourceGroup().name
  }
  {
    roleDefinitionId: 'c12c1c16-33a1-487b-954d-41c89c60f349' // Reader and Data Access (NTFS Permissions - Get storage account key)
    scope: ResourceGroupStorage
  }
] : []
var FSLogixPrivateEndpointRoleAssignment = contains(FslogixStorage, 'PrivateEndpoint') ? [
  {
    roleDefinitionId: '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor (Private Endpoint - Configure DNS resolution)
    scope: VirtualNetworkResourceGroupName
  }
] : []
var FSLogixRoleAssignments = union(FSLogixNtfsRoleAssignments, FSLogixPrivateEndpointRoleAssignment)
var RoleAssignments = union(DiskEncryptionRoleAssignment, DrainModeRoleAssignment, FSLogixRoleAssignments)

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: UserAssignedIdentityName
  location: Location
}

module roleAssignments 'roleAssignment.bicep' = [for i in range(0, length(RoleAssignments)): {
  name: 'UAI_RoleAssignment_${i}_${Timestamp}'
  scope: resourceGroup(RoleAssignments[i].scope)
  params: {
    PrincipalId: userAssignedIdentity.properties.principalId
    RoleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleAssignments[i].roleDefinitionId)
  }
}]

output principalId string = userAssignedIdentity.properties.principalId
output id string = userAssignedIdentity.id