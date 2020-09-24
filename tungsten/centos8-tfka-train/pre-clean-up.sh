pip uninstall -y -r <(pip freeze --path /usr/local/lib/python3.6/site-packages/ --path /usr/local/lib64/python3.6/site-packages/)
dnf reinstall `rpm -qa|grep python`
