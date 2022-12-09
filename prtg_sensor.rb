# For more info about writing custom resources:
# https://gist.github.com/lamont-granquist/8cda474d6a31fadd3bb3b47a66b0ae78

resource_name :prtg_sensor
property :prtg_url, String
property :username, String
property :password, String
property :ip_address, String, default: node['ipaddress'].to_s
property :ps_module_name, String, default: 'PrtgAPI'
property :node_name, String, default: (Chef::Config[:node_name]).to_s

default_action :create
action :create do
  case node['platform']
  when 'windows'
    powershell_script "Install module #{new_resource.ps_module_name}" do
      code "Install-Package #{new_resource.ps_module_name} -Force"
      not_if "$(get-package #{new_resource.ps_module_name}).Name -eq '#{new_resource.ps_module_name}'"
    end

    powershell_script 'Configure Windows sensors' do
      code <<-EOF
          Connect-PrtgServer #{new_resource.prtg_url} (New-Credential #{new_resource.username} #{new_resource.password} ) -PassHash -Force
          get-probe -Id 1 | Add-Device "#{new_resource.node_name}" -Host "#{node['ipaddress']}"
          Get-Device -Name "#{new_resource.node_name}" | Move-Object 3763
          $computerid=(Get-Device "#{new_resource.node_name}").id
          #https://stackoverflow.com/questions/29973212/pipe-complete-array-objects-instead-of-array-items-one-at-a-time
          #unary array operator ,
          $sensor_array = ("3446", "3611 ", "3677", "3777")
          ,$sensor_array | foreach{  Get-Sensor -Id $_ | Clone-Object -DestinationId $computerid }
          out-file "#{Chef::Config[:file_cache_path]}\\prtg_configured" -force
          EOF
      not_if { ::File.file?("#{Chef::Config[:file_cache_path]}\\prtg_configured") }
    end

  when 'redhat'
    bash 'Configure Linux sensors' do
      code <<-EOF
        yum install -y net-snmp net-snmp-libs net-snmp-utils
        # Register the Microsoft RedHat repository
        curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
        #install powershell
        sudo yum install -y powershell
        #backup snmpd default config
        cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf-bak
        EOF
      not_if { ::File.file?("#{Chef::Config[:file_cache_path]}/prtg_configured") }
    end

    # Set SNMP config file
    template '/etc/snmp/snmpd.conf' do
      source 'snmp.conf.erb'
      mode '0777'
      owner 'root'
      group 'root'
    end

    # restart snmpd
    bash 'Restart SNMPD' do
      code <<-EOF
      systemctl restart snmpd
      EOF
    not_if { ::File.file?("#{Chef::Config[:file_cache_path]}/prtg_configured") }
    end

    # Write powershell PRTG setup script to disk
    template '/prtg_setup.ps1' do
      source '/prtg_setup.ps1.erb'
      mode '0777'
      owner 'root'
      group 'root'
      variables(
        username:      new_resource.username,
        password:      new_resource.password,
        prtg_url:      new_resource.prtg_url
      )
    end

    # run PowerShell script
    bash 'Run powershell script' do
      code <<-EOF
      pwsh /prtg_setup.ps1
      EOF
      not_if { ::File.file?("#{Chef::Config[:file_cache_path]}/prtg_configured") }
    end
  end
end
