sudo docker compose down --rmi all --volumes --remove-orphans
sudo docker compose build
sudo docker compose up -d
sudo docker exec dc /usr/helpers/samba-provision.sh
sudo docker exec -it dc samba-tool user setpassword Administrator
# # samba-tool user setpassword Administrator
# & docker compose down
# & docker compose up -d
# & docker exec -it dc samba-tool user setpassword Administrator