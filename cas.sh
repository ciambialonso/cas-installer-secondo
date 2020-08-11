#!/bin/bash
programname=$0
DEFAUTL_CAS_VERSION=0.9.1


function printLogo
{
	echo "                                                                        ";
	echo "                                                                        ";
	echo "        CCCCCCCCCCCCC               AAA                 SSSSSSSSSSSSSSS ";
	echo "     CCC::::::::::::C              A:::A              SS:::::::::::::::S";
	echo "   CC:::::::::::::::C             A:::::A            S:::::SSSSSS::::::S";
	echo "  C:::::CCCCCCCC::::C            A:::::::A           S:::::S     SSSSSSS";
	echo " C:::::C       CCCCCC           A:::::::::A          S:::::S            ";
	echo "C:::::C                        A:::::A:::::A         S:::::S            ";
	echo "C:::::C                       A:::::A A:::::A         S::::SSSS         ";
	echo "C:::::C                      A:::::A   A:::::A         SS::::::SSSSS    ";
	echo "C:::::C                     A:::::A     A:::::A          SSS::::::::SS  ";
	echo "C:::::C                    A:::::AAAAAAAAA:::::A            SSSSSS::::S ";
	echo "C:::::C                   A:::::::::::::::::::::A                S:::::S";
	echo " C:::::C       CCCCCC    A:::::AAAAAAAAAAAAA:::::A               S:::::S";
	echo "  C:::::CCCCCCCC::::C   A:::::A             A:::::A  SSSSSSS     S:::::S";
	echo "   CC:::::::::::::::C  A:::::A               A:::::A S::::::SSSSSS:::::S";
	echo "     CCC::::::::::::C A:::::A                 A:::::AS:::::::::::::::SS ";
	echo "        CCCCCCCCCCCCCAAAAAAA                   AAAAAAASSSSSSSSSSSSSSS   ";
	echo "                                                                        ";
	echo "                                                                        ";
	echo "                                                                        ";
	echo "                                                                        ";
	echo "                                                                        ";
	echo "                                                                        ";
	echo "                                                                        ";
}

# Print usage guide
function usage {
  echo "usage: $programname COMMAND"
  echo "  -------- COMMANDS -------"
  echo "  -i {site url} [version number]   Verify requirements and start installation"
  echo "  -r                               Start the system"
  echo "  -s                               Stop the system"
  echo "  -d                               Remove the system"
  echo "  -u {version number}              Search for updates"
  echo "  -h                               Show help"
  exit 1
}

function install() {
	echo "Starting CAS System Installation v. $1"
  # Checking for requirements
  echo "  [INSTALL 1/10] Checking requirements.."
  if exists docker; then
    echo "    DOCKER .............................. OK";
  else
    echo "    DOCKER .............................. NOT FOUND";
    exit 1;
  fi
  if exists docker-compose; then
    echo "    DOCKER-COMPOSE ...................... OK";
  else
    echo "    DOCKER-COMPOSE ...................... NOT FOUND";
    exit 1;
  fi
  
  if exists nginx; then
    echo "    NGINX ............................... OK";
  else
    echo "    NGINX ............................... NOT FOUND";
    sudo apt-get install nginx;
  fi

  # Download CAS repos with git
  echo "  [INSTALL 2/10] Start downloading CAS repository"
  git clone --branch $1 https://github.com/ciambialonso/cas-server.git cas-components

  # Change file permissions
  sudo chmod 755 -R cas-components 
  
  cd cas-components

  # Start Gitlab INSTALLATION
  echo "  [INSTALL 3/10] Installing GitLab"
  yes | cp -rf ../gitlab.env docker-gitlab/.env
  g_siteurl="CAS_GITLAB_OMNIBUS_CONFIG=external_url '"
  g_siteurl+=$2
  g_siteurl+="'"
  echo $g_siteurl >> docker-gitlab/.env
  cd docker-gitlab
  sudo docker-compose up -d

  # Start Mattermost INSTALLATION
  cd ../
  echo "  [INSTALL 4/10] Installing Mattermost"
  yes | cp -rf ../mattermost.env docker-mattermost/.env
  m_siteurl="CAS_MATTERMOST_SITEURL="
  m_siteurl+=$2
  echo $m_siteurl >> docker-mattermost/.env
  cd docker-mattermost
  sudo docker-compose build
  sudo docker-compose up -d

  # Start Sonarqube INSTALLATION
  cd ../
  echo "  [INSTALL 5/10] Installing Sonarqube"
  yes | cp -rf ../sonar.env docker-sonar/.env
  cd docker-sonar
  sudo docker-compose up -d

  # Start Taiga INSTALLATION
  cd ../
  echo "  [INSTALL 6/10] Installing Taiga"
  yes | cp -rf ../taiga.env docker-taiga/.env
  cd docker-taiga
  sudo docker-compose build
  sudo docker-compose up -d

  # Start Bugzilla INSTALLATION
  cd ../
  echo "  [INSTALL 7/10] Installing Bugzilla"
  yes | cp -rf ../bugzilla.env docker-bugzilla/.env
  cd docker-bugzilla
  sudo docker-compose build
  sudo docker-compose up -d

  # Start Logger INSTALLATION
  cd ../
  echo "  [INSTALL 8/10] Installing Logger"
  yes | cp -rf ../logger.env docker-logger/.env
  cd docker-logger
  sudo docker-compose build
  sudo docker-compose up -d

  # Wait for operation completion
  echo "  [INSTALL 9/10] Waiting for operations' completion"
  cd ../../
  sudo service nginx stop
  sudo rm /etc/nginx/sites-available/default
  sudo cp default /etc/nginx/sites-available/default
    
  # Replacing site ports
  p_gitlab=$(cut -d "=" -f 2 <<< $(head -n 1 gitlab.env))
  p_bugzilla=$(cut -d "=" -f 2 <<< $(head -n 1 bugzilla.env))
  p_sonar=$(cut -d "=" -f 2 <<< $(head -n 1 sonar.env))
  p_mattermost=$(cut -d "=" -f 2 <<< $(head -n 1 mattermost.env))
  
  sed_str='s+CAS_GITLAB_PORT+'
  sed_str+=$p_gitlab
  sed_str+='+g'
  sed -i $sed_str /etc/nginx/sites-available/default
  
  sed_str='s+CAS_BUGZILLA_PORT+'
  sed_str+=$p_bugzilla
  sed_str+='+g'
  sed -i $sed_str /etc/nginx/sites-available/default
  
  sed_str='s+CAS_SONAR_PORT+'
  sed_str+=$p_sonar
  sed_str+='+g'
  sed -i $sed_str /etc/nginx/sites-available/default
  
  sed_str='s+CAS_MATTERMOST_PORT+'
  sed_str+=$p_mattermost
  sed_str+='+g'
  sed -i $sed_str /etc/nginx/sites-available/default
  
  sudo service nginx restart
  sleep 10


  # Operation completion, print information data
  echo "  [INSTALL 10/10] Installation Completed"
}



# Run all services
function startAll {
  echo "Starting CAS System..."
  cd cas-components

  # Start Gitlab
  echo "  [START 1/8] Starting GitLab"
  cd docker-gitlab
  sudo docker-compose start


  # Start Mattermost
  cd ../
  echo "  [START 2/8] Starting Mattermost"
  cd docker-mattermost
  sudo docker-compose start

  # Start Sonarqube
  cd ../
  echo "  [START 3/8] Starting Sonarqube"
  cd docker-sonar
  sudo docker-compose start

  # Start Taiga
  cd ../
  echo "  [START 4/8] Starting Taiga"
  cd docker-taiga
  sudo docker-compose start

  # Start Bugzilla
  cd ../
  echo "  [START 5/8] Starting Bugzilla"
  cd docker-bugzilla
  sudo docker-compose start

  # Start Logger
  cd ../
  echo "  [START 6/8] Stopping Logger"
  cd docker-logger
  sudo docker-compose start

  # Wait for operation completion
  echo "  [START 7/8] Waiting for operations' completion"
  sleep 10


  # Operation completion, print information data
  echo "  [START 8/8] All services are now running"
}


# Stop all services
function stopAll {
  echo "Stopping CAS System..."
  cd cas-components

  # Stop Gitlab
  echo "  [STOP 1/8] Stopping GitLab"
  cd docker-gitlab
  sudo docker-compose stop


  # Stop Mattermost
  cd ../
  echo "  [STOP 2/8] Stopping Mattermost"
  cd docker-mattermost
  sudo docker-compose stop

  # Stop Sonarqube
  cd ../
  echo "  [STOP 3/8] Stopping Sonarqube"
  cd docker-sonar
  sudo docker-compose stop

  # Stop Taiga
  cd ../
  echo "  [STOP 4/8] Stopping Taiga"
  cd docker-taiga
  sudo docker-compose stop

  # Stop Bugzilla
  cd ../
  echo "  [STOP 5/8] Stopping Bugzilla"
  cd docker-bugzilla
  sudo docker-compose stop

  # Stop Logger
  cd ../
  echo "  [STOP 6/8] Stopping Logger"
  cd docker-logger
  sudo docker-compose stop

  # Wait for operation completion
  echo "  [STOP 7/8] Waiting for operations' completion"
  sleep 10


  # Operation completion, print information data
  echo "  [STOP 8/8] All services are now stopped"
}




# Delete all services
function deleteAll {
  echo "Deleting CAS System..."
  cd cas-components

  # Delete Gitlab
  echo "  [DELETE 1/8] Deleting GitLab"
  cd docker-gitlab
  sudo docker-compose rm


  # Delete Mattermost
  cd ../
  echo "  [DELETE 2/8] Deleting Mattermost"
  cd docker-mattermost
  sudo docker-compose rm

  # Delete Sonarqube
  cd ../
  echo "  [DELETE 3/8] Deleting Sonarqube"
  cd docker-sonar
  sudo docker-compose rm

  # Delete Taiga
  cd ../
  echo "  [DELETE 4/8] Deleting Taiga"
  cd docker-taiga
  sudo docker-compose rm

  # Delete Bugzilla
  cd ../
  echo "  [DELETE 5/8] Deleting Bugzilla"
  cd docker-bugzilla
  sudo docker-compose rm

  # Delete Logger
  cd ../
  echo "  [DELETE 6/8] Deleting Logger"
  cd docker-logger
  sudo docker-compose rm

  # Wait for operation completion
  echo "  [DELETE 7/8] Waiting for operations' completion"
  sleep 10


  # Operation completion, print information data
  echo "  [STOP 8/8] All services has been removed"
}

exists()
{
  command -v "$1" >/dev/null 2>&1
}

printLogo
sleep 5

if [ "$#" -lt 1 ]; then
  usage
fi

while getopts ":hirsdu:" opt; do
  case $opt in
    h)
      usage
      ;;
    i)
      shift $(($OPTIND - 1))
	  site_url=$@
	  shift $(($OPTIND - 1))
	  cas_ver=$@
      if [ -z "$cas_ver" ]
      then
        install $site_url $DEFAUTL_CAS_VERSION
      else
        install $site_url $cas_ver
      fi
      ;;
    r)
      startAll
      ;;
    s)
      stopAll
      ;;
    d)
      deleteAll
      # Remove all volumes with persistent data
      sudo docker volume prune
      sudo docker network prune
      ;;
    u)
      cas_ver=$OPTARG
      deleteAll
      install $cas_ver
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
    ;;
  esac
done

exit 1
