# Hadoop
if (node['hadoop'].has_key? 'core_site' and node['hadoop']['core_site'].has_key? 'hadoop.security.authorization' and
  node['hadoop']['core_site'].has_key? 'hadoop.security.authentication' and
  node['hadoop']['core_site']['hadoop.security.authorization'] == 'true' and
  node['hadoop']['core_site']['hadoop.security.authentication'].downcase == 'kerberos')

  include_attribute 'krb5'
  include_attribute 'krb5_utils'

  # hadoop-env.sh
  default['hadoop']['hadoop_env']['jsvc_home'] = '/usr/libexec/bigtop-utils'
  default['hadoop']['hadoop_env']['hadoop_secure_dn_user'] = 'hdfs'
  default['hadoop']['hadoop_env']['hadoop_secure_dn_pid_dir'] = '/var/run/hadoop-hdfs'
  default['hadoop']['hadoop_env']['hadoop_secure_dn_log_dir'] = '/var/log/hadoop-hdfs'

  # hdfs-site.xml
  default['hadoop']['hdfs_site']['dfs.block.access.token.enable'] = true
  default['hadoop']['hdfs_site']['dfs.datanode.kerberos.principal'] = "hdfs/_HOST@#{node['krb5']['default_realm']}"
  default['hadoop']['hdfs_site']['dfs.namenode.kerberos.principal'] = "hdfs/_HOST@#{node['krb5']['default_realm']}"
  default['hadoop']['hdfs_site']['dfs.web.authentication.kerberos.principal'] = "HTTP/_HOST@#{node['krb5']['default_realm']}"
  default['hadoop']['hdfs_site']['dfs.datanode.keytab.file'] = "#{node['krb5_utils']['keytabs_dir']}/hdfs.service.keytab"
  default['hadoop']['hdfs_site']['dfs.namenode.keytab.file'] = "#{node['krb5_utils']['keytabs_dir']}/hdfs.service.keytab"
  default['hadoop']['hdfs_site']['dfs.datanode.address'] = "0.0.0.0:1004"
  default['hadoop']['hdfs_site']['dfs.datanode.http.address'] = "0.0.0.0:1006"

end
