trigger:
- main

pool:
  name: default
  demands:
    - agent.name -equals mngt

variables:
  # Set these variables in your pipeline or variable group
  AKS_RESOURCE_GROUP: 'aksmngpoc'
  AKS_CLUSTER_NAME: 'pcaksgraf2 '
  AZURE_CLIENT_ID: 'a2c02248-b5dd-4373-8373-034f3225c525'
  AZURE_TENANT_ID: '72958850-e7e7-4b9c-a59c-0418c1d5bf91'

stages:
- stage: Deploy
  displayName: 'Deploy to Kubernetes with Workload Identity'
  jobs:
  - job: KubernetesDeployment
    displayName: 'Deploy using Workload Identity'
    steps:
    
    # Step 1: Retrieve ID Token and Store
    - task: AzureCLI@2
      displayName: 'Retrieve ID Token and Store'
      inputs:
        azureSubscription: 'SC-Federated'
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          # Get ID Token using Azure CLI
          IDTOKEN=$(az account get-access-token --resource api://AzureADTokenExchange --query accessToken -o tsv)
          
          # Store token in temp file
          echo $IDTOKEN > $(Agent.TempDirectory)/.token
          
          # JWT decoder function
          jwtd() {
              if [[ -x $(command -v jq) ]]; then
                  jq -R 'split(".") | .[0],.[1] | @base64d | fromjson' <<< "${1}"
                  echo "Signature: $(echo "${1}" | awk -F'.' '{print $3}')"
              fi
          }
          
          # Decode and display token info
          jwtd $IDTOKEN
          
          # Set output variable for use in subsequent tasks
          echo "##vso[task.setvariable variable=idToken;isOutput=true]${IDTOKEN}"
      name: getToken

    # Step 2: Install kubelogin
    - task: Bash@3
      displayName: 'Install kubelogin'
      inputs:
        targetType: 'inline'
        script: |
          # Create temp directory and download
          cd $(Agent.TempDirectory)
          echo "Downloading kubelogin..."
          curl -LO https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip
          
          # Extract and verify contents
          echo "Extracting kubelogin..."
          unzip -o kubelogin-linux-amd64.zip
          ls -la
          find . -name "kubelogin" -type f
          
          # Make executable and move to PATH
          chmod +x bin/linux_amd64/kubelogin
          
          # Try different installation paths
          if sudo mv bin/linux_amd64/kubelogin /usr/local/bin/; then
            echo "Installed to /usr/local/bin/"
          elif mkdir -p ~/bin && cp bin/linux_amd64/kubelogin ~/bin/; then
            echo "Installed to ~/bin/"
            export PATH="$HOME/bin:$PATH"
          else
            echo "Installing to current directory and adding to PATH"
            cp bin/linux_amd64/kubelogin .
            export PATH="$(pwd):$PATH"
            echo "##vso[task.setvariable variable=PATH]$(pwd):$PATH"
          fi
          
          # Verify installation
          which kubelogin || echo "kubelogin not found in PATH"
          kubelogin --version || ./kubelogin --version

    # Step 3: Setup kubeconfig
    - task: AzureCLI@2
      displayName: 'Setup kubeconfig'
      inputs:
        azureSubscription: 'SC-Federated'
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          # Download kubeconfig for your AKS cluster
          az aks get-credentials --resource-group $(AKS_RESOURCE_GROUP) --name $(AKS_CLUSTER_NAME) --overwrite-existing
          
          # Set KUBECONFIG environment variable for subsequent tasks
          echo "##vso[task.setvariable variable=KUBECONFIG]$HOME/.kube/config"
          
          # Verify kubeconfig
          echo "Current kubeconfig context:"
          kubectl config current-context
          echo "Cluster info:"
          kubectl config view --minify

    # Step 4: Convert kubeconfig for workload identity
    - task: Bash@3
      displayName: 'Convert kubeconfig'
      inputs:
        targetType: 'inline'
        script: |
          # Set KUBECONFIG environment variable as per documentation
          export KUBECONFIG=$HOME/.kube/config
          
          # Ensure kubelogin is in PATH
          export PATH="$(Agent.TempDirectory):$PATH"
          
          # Verify kubeconfig exists and is valid
          if [ ! -f "$KUBECONFIG" ]; then
            echo "Error: kubeconfig not found at $KUBECONFIG"
            exit 1
          fi
          
          echo "Current kubeconfig before conversion:"
          kubectl config view --minify
          
          # Convert kubeconfig for workload identity as per documentation
          if command -v kubelogin >/dev/null 2>&1; then
            kubelogin convert-kubeconfig -l workloadidentity
          else
            echo "Using kubelogin from temp directory"
            $(Agent.TempDirectory)/kubelogin convert-kubeconfig -l workloadidentity
          fi
          
          echo "Kubeconfig after conversion:"
          kubectl config view --minify

    # Step 5: Run kubectl with workload identity
    - task: Bash@3
      displayName: 'Run kubectl'
      inputs:
        targetType: 'inline'
        script: |
          # Set KUBECONFIG environment variable as per documentation
          export KUBECONFIG=$HOME/.kube/config
          
          # Ensure kubelogin is in PATH for kubectl to use
          export PATH="$(Agent.TempDirectory):$PATH"
          
          # Set the required environment variables as per kubelogin documentation
          export AZURE_CLIENT_ID=$(AZURE_CLIENT_ID)
          export AZURE_TENANT_ID=$(AZURE_TENANT_ID)
          export AZURE_FEDERATED_TOKEN_FILE=$(Agent.TempDirectory)/.token
          export AZURE_AUTHORITY_HOST=https://login.microsoftonline.com/
          
          echo "Environment variables set as per kubelogin documentation:"
          echo "KUBECONFIG: $KUBECONFIG"
          echo "AZURE_AUTHORITY_HOST: $AZURE_AUTHORITY_HOST"
          echo "AZURE_CLIENT_ID: $AZURE_CLIENT_ID" 
          echo "AZURE_TENANT_ID: $AZURE_TENANT_ID"
          echo "AZURE_FEDERATED_TOKEN_FILE: $AZURE_FEDERATED_TOKEN_FILE"
          
          # Verify token file exists
          if [ -f "$AZURE_FEDERATED_TOKEN_FILE" ]; then
            echo "Federated token file found"
            echo "Token file size: $(wc -c < $AZURE_FEDERATED_TOKEN_FILE) bytes"
          else
            echo "Error: Federated token file not found at $AZURE_FEDERATED_TOKEN_FILE"
            exit 1
          fi
          
          # Run kubectl as per documentation example
          kubectl get nodes
          
          # Additional kubectl commands you might want to run
          # kubectl get pods --all-namespaces
          # kubectl apply -f your-manifest.yaml
      env:
        AZURE_CLIENT_ID: $(AZURE_CLIENT_ID)
        AZURE_TENANT_ID: $(AZURE_TENANT_ID)
