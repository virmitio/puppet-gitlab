# Class: gitlab::user
#
# This Class defines the creation and assignment of gitlab users and groups
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
  if $email =~ /^.*@.*\..*$/ {
    if $username =~ /^(.*)@.*$/ {
      $user_name = $1
    }
    exec {"add-gitlab-user-${username}":
      command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"insert into users (email, encrypted_password, Sign_in_count, created_at, updated_at, name, username, admin, projects_limit, can_create_group, can_create_team, state) values ('${email}', '${pass}', 1, NOW(), NOW(), '${user_name}', '${user_name}', 1, 500, 1, 1, 'active')\"",
      unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select count(id) from users where (email like '${email}') or (username like '${user_name}')\"`\"",
    }
    $keys = ($ssh_keys.each { |$index, $val|  gitlab::ssh_key{ "${title}-key-${index}": 
        keystring => $val, 
        user_email => $email,
        require => Exec["add-gitlab-user-${username}"],
        } } 
    )
  } else {
    fail("Error adding user '${email}', not a valid email address.")
  }
}

define gitlab::group (
  $name = $title,
  $owner = UNSET,
  $dbuser = hiera('gitlab::gitlab_dbuser'),
  $dbname = hiera('gitlab::gitlab_dbname'),
  $dbpwd = hiera('gitlab::gitlab_dbpwd'),
) {
  if $owner == UNSET {
    $owner_ = '%'
  }
  exec {"add-group-${name}":
    command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"insert into namespaces (name, path, type created_at, updated_at, owner_id) values ('${name}', Lower('${name}'), 'Group', NOW(), NOW(), (select id from users where email like '${owner_}' order by id limit 1))\"",
    unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select count(id) from namespaces where Lower(name) like Lower('${name}')\"`\"",
  }
}

define gitlab::group_user (
  $user_email,
  $groupname,
  $access = hiera('gitlab::group_user::access'), #acceptable values, lowest to highest:  10, 20, 30, 40, 50
  $dbuser = hiera('gitlab::gitlab_dbuser'),
  $dbname = hiera('gitlab::gitlab_dbname'),
  $dbpwd = hiera('gitlab::gitlab_dbpwd'),
) {
  exec {"add-groupuser-${name}":
    command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"insert into users_groups (group_id, user_id, group_access, created_at, updated_at, notification_level) values ((select id from namespaces where Lower(name) like Lower('${groupname}') limit 1), (select id from users where (email like '${user_email}') limit 1), ${access}, NOW(), NOW(), 3)\"",
    unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select (select count(id) from namespaces where Lower(name) like Lower('${groupname}')) and (select count(id) from users where (email like '${user_email}'))\"`\"",
  }
}

define gitlab::block_user (
  $user_email = $title,
) {
    exec {"block-gitlab-user-${user_email}":
      command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"update users set state='blocked' where email like '${user_email}'\"",
      unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select count(id)=1 from users where (email like '${user_email}')\"`\"",
    }
}

define gitlab::cripple_user (
  $user_email = $title,
) {
    exec {"cripple-gitlab-user-${user_email}":
      command => "/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"update users set encrypted_password=NULL where email like '${user_email}'\"",
      unless  => "/bin/sh -c \"! return `/usr/bin/mysql -u${dbuser} -p${dbpwd} -D${dbname} -N -B -e\"select count(id)=1 from users where (email like '${user_email}')\"`\"",
      require => Gitlab::Block_user["${user_email}"],
    }
}
