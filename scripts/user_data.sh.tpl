#!/bin/bash
# Redirection des logs vers /var/log/user-data.log pour le débogage
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "🛠 1. Préparation du système..."
# Mise à jour et installation des outils de base pour récupérer le code
dnf update -y
dnf install -y git ansible

echo "📂 2. Récupération du code..."
# Si privé : https://<TOKEN>@github.com/user/repo.git
git clone -b ${branch_name} https://github.com/Adam-Doria/Cloud-computing-Green-leaft /opt/greenleaf
cd /opt/greenleaf

echo "🤖 3. Exécution du Playbook Ansible (Configuration)..."
# On lance le playbook en local. Il va installer Docker, configurer l'user, etc.
cd ansible
ansible-playbook playbook.yml

echo "📝 4. Configuration de l'environnement (Secrets)..."
# On remonte dans le dossier app pour générer le .env
cd ../app

# Injection dynamique des variables par Terraform
cat <<EOF > .env
DATABASE_URL=${db_url}
REDIS_URL=${redis_url}
S3_URL=${s3_url}
S3_ACCESS_KEY_ID=${s3_key}
S3_SECRET_ACCESS_KEY=${s3_secret}
PORT=9000
# Ajoutez ici d'autres variables si nécessaire (ex: JWT_SECRET, COOKIE_SECRET)
EOF

echo "🚀 5. Lancement de l'Application..."
# On utilise le chemin complet du plugin Docker Compose (installé par Ansible)
/usr/local/lib/docker/cli-plugins/docker-compose up -d

echo "✅ Déploiement terminé."