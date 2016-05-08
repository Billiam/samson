#!/bin/bash
if [ ! -f /usr/bin/ansible-playbook ]
    then
    apt-get install software-properties-common
    apt-add-repository ppa:ansible/ansible
    apt-get update
    apt-get install -y ansible
fi

# copy hosts file out of shared directory to work around executable behavior
# See:
#   - https://github.com/ansible/ansible/pull/10369
#   - https://github.com/ansible/ansible/issues/10068
cp /vagrant/ansible/development /etc/ansible/hosts
chmod -x /etc/ansible/hosts

# Install galaxy roles from yaml, if present. File must not be empty
# See:
#   - https://github.com/ansible/ansible/commit/0e778714262479258bd612910469e20e674e8a3b
[ -f /vagrant/ansible/roles.yml ] && ansible-galaxy install -r /vagrant/ansible/roles.yml

ansible-playbook /vagrant/ansible/site.yml --verbose