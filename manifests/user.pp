# Class: gitlab::user
#
# This Class defines the creation of gitlab users
#

define gitlab::ssh_key ($keystring, $user_email) {

  if $keystring =~ /^(?:(.*-.*)\s)?(.*)\s?(.*)?$/ {
    if $1 =~ /ssh-(?:rsa|dss)/ {
      $type = $1
    } else {
      $type = 'ssh-rsa'
    }
    $key = $2
    $comment = $3
  }
  $fingerprint = regsubst( 
    regsubst( 
      md5($key), '(.[^$])', '\1:', 'G'
    ), 
    '(..):$', 
    '\1'
  )

  $keystr = "${type} ${key} ${comment}"
  exec {"add-gitlab-ssh-key-${key}":
    command => "/usr/bin/mysql -u${gitlab_dbuser} -p${gitlab_dbpwd} -D${gitlab_dbname} -N -B -e\"insert into ${gitlab_dbname}.keys (user_id, title, ${gitlab_dbname}.keys.key, fingerprint) values ((select id from users where email='${user_email}' limit 1), '${name}', '${keystr}', '${fingerprint}')\"",
    unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${gitlab_dbuser} -p${gitlab_dbpwd} -D${gitlab_dbname} -N -B -e\"select count(id) from ${gitlab_dbname}.keys where ${gitlab_dbname}.keys.key like '${keystr}'\"`\"",
  }
  
#  $type = regsubst( $keystring, '^(?:(.*-.*)\s)?(.*)\s?(.*)?$', '\1' ),
#  $key = regsubst( $keystring, '^(?:(.*-.*)\s)?(.*)\s?(.*)?$', '\2' ),
#  $comment = regsubst( $keystring, '^(?:(.*-.*)\s)?(.*)\s?(.*)?$', '\3' ),
}

define gitlab::user ($email = $title, $username, $pass, $ssh_keys = []) {
#  $keys = ($ssh_keys.each {|$index, $val| class gitlab::ssh_key{"key${index}": keystring => $val} })
#  $keys = [],
#  $ssh_keys.each {|$index, $val| gitlab::ssh_key{"key${index}": keystring => $val} }
  exec {"add-gitlab-user-${username}":
    command => "/usr/bin/mysql -u${gitlab_dbuser} -p${gitlab_dbpwd} -D${gitlab_dbname} -N -B -e\"insert into users (email, encrypted_password, Sign_in_count, created_at, name, username, admin, projects_limit, can_create_group, can_create_team) values ('${email}', '${pass}', 1, NOW(), '${username}', '${username}', 1, 500, 1, 1)\"",
    unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${gitlab_dbuser} -p${gitlab_dbpwd} -D${gitlab_dbname} -N -B -e\"select count(id) from users where email like '${email}'\"`\"",
  }
  $keys = ($ssh_keys.each { |$index, $val|  gitlab::ssh_key{ "${title}-key-${index}": 
      keystring => $val, 
      user_email => $email} } )
  
}



