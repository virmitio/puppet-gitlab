# Class: gitlab::user
#
# This Class defines the creation of gitlab users
#

define gitlab::ssh_key (
  $keystring,
  $user_email,
  $dbuser = hiera('gitlab::gitlab_dbuser'),
  $dbname = hiera('gitlab::gitlab_dbname'),
  $dbpwd = hiera('gitlab::gitlab_dbpwd'),
) {
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
    command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"insert into ${dbname}.keys (user_id, title, ${dbname}.keys.key, fingerprint, created_at, updated_at) values ((select id from users where email='${user_email}' limit 1), '${name}', '${keystr}', '${fingerprint}', Now(), Now())\"",
    unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select count(id) from ${dbname}.keys where ${dbname}.keys.key like '${keystr}'\"`\"",
  }
  
#  $type = regsubst( $keystring, '^(?:(.*-.*)\s)?(.*)\s?(.*)?$', '\1' ),
#  $key = regsubst( $keystring, '^(?:(.*-.*)\s)?(.*)\s?(.*)?$', '\2' ),
#  $comment = regsubst( $keystring, '^(?:(.*-.*)\s)?(.*)\s?(.*)?$', '\3' ),
}

define gitlab::user (
  $email = $title,
  $username = $title,
  $pass = hiera('gitlab::user::pass'),
  $ssh_keys = [],
  $dbuser = hiera('gitlab::gitlab_dbuser'),
  $dbname = hiera('gitlab::gitlab_dbname'),
  $dbpwd = hiera('gitlab::gitlab_dbpwd'),
) {
  exec {"add-gitlab-user-${username}":
    command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"insert into users (email, encrypted_password, Sign_in_count, created_at, name, username, admin, projects_limit, can_create_group, can_create_team) values ('${email}', '${pass}', 1, NOW(), '${username}', '${username}', 1, 500, 1, 1)\"",
    unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select count(id) from users where email like '${email}'\"`\"",
  }
  $keys = ($ssh_keys.each { |$index, $val|  gitlab::ssh_key{ "${title}-key-${index}": 
      keystring => $val, 
      user_email => $email,
      require => Exec["add-gitlab-user-${username}"],
      } } 
  )
}



