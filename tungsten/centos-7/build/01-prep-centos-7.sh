yum install -y git
git clone http://github.com/tungstenfabric/tf-dev-env

# setup DEVENV container
tf-dev-env/run.sh
# - common/functions.sh:function install_prerequisites_centos()
#     yum install -y lsof python
# - common/setup_docker.sh:
# - common/setup_docker_registry.sh
# - common/functions.sh:function load_tf_devenv_profile()
#     source ~/.tf/dev.env
# - make common.env from common.env.tmpl
# - common/tf_functions.sh:function create_env_file()
#     input/tf-developer-sandbox.env
# - cp tpc.repo config/etc/yum.repos.d/
# - cd container/build.sh ${DEVENV_IMAGE_NAME} ${DEVENV_TAG}
# - docker run --network host --privileged --detach --name $DEVENV_CONTAINER_NAME -w /$DEVENV_USER ${options} $volumes -it ${CONTAINER_REGISTRY}/${DEVENV_IMAGE}

# upload:
#   CONTAINER_REGISTRY={x} tf-dev-env/run.sh upload $container
#     docker stop,commit,push ${CONTAINER_REGISTRY}/${DEVENV_IMAGE_NAME}:${DEVENV_PUSH_TAG}

# build = fetch configure compile package
tf-dev-env/run.sh build
tf-dev-env/run.sh test
# - docker exec -i $DEVENV_CONTAINER_NAME /$DEVENV_USER/tf-dev-env/container/run.sh $stage $target
# - python3 -u $HOME/contrail/third_party/fetch_packages.py --site-mirror $SITE_MIRROR
