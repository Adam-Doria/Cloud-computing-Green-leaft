# 📘 GreenLeaf : Guide d'Architecture & Implémentation

## 1. Vue d'Ensemble de l'Architecture
Nous déployons une architecture **Hybride (Multi-Cloud)** et **Haute Disponibilité (HA)** conçue pour tenir un trafic e-commerce tout en respectant un budget strict de 500$/mois.

### 🗺️ Le Flux de Données (Request Flow)
1.  **Utilisateur** : Tape `greenleaf.com`.
2.  **Cloudflare (Edge)** :
    *   Reçoit la requête.
    *   Vérifie la sécurité (WAF/DDoS).
    *   Sert le contenu statique (Images, CSS) depuis son cache.
    *   *Si c'est une image produit* : La sert directement depuis le bucket **R2**.
    *   *Si c'est du dynamique* : Transfère la requête vers AWS.
3.  **AWS Load Balancer (ALB)** : Reçoit le trafic filtré sur le port 80.
4.  **Auto Scaling Group (Compute)** :
    *   L'ALB choisit l'instance la moins chargée (Zone A ou Zone B).
    *   **Caddy (Reverse Proxy)** reçoit la requête sur l'instance.
    *   Caddy la passe au conteneur **Medusa Backend** ou **Storefront**.
5.  **Données & Persistance** :
    *   Medusa lit/écrit dans **RDS PostgreSQL** (Données clients).
    *   Medusa stocke la session dans **Redis** (Cache partagé).
    *   Pour sortir sur Internet (ex: Stripe), Medusa passe par la **NAT Instance**.

---

## 2. Rôles des Outils (Qui fait quoi ?)

C'est ici qu'on évite la confusion.

### 🏗️ Terraform : Le Maçon (Infrastructure Provisioning)
Terraform construit les "murs" de la maison. Il parle à l'API AWS.
*   **Ce qu'il gère :**
    *   Le réseau (VPC, Subnets, Route Tables).
    *   Les services managés (RDS, ElastiCache, ALB).
    *   Les règles de sécurité (Security Groups).
    *   Les définitions de scaling (Auto Scaling Group, Launch Template).
*   **Commandes clés :** `terraform plan`, `terraform apply`.

### 🛠️ Ansible / User Data : L'Électricien & Décorateur (Configuration Management)
Une fois les murs construits (EC2 lancée), il faut installer les logiciels.
*   **Ce qu'il gère :**
    *   Mise à jour Linux (`dnf update`).
    *   Installation de **Docker** et **Docker Compose**.
    *   Création des fichiers de configuration (`.env`).
    *   Lancement de l'application.
*   **Implémentation GreenLeaf :**
    *   Pour gagner du temps, nous n'utiliserons pas un serveur Ansible maître complexe.
    *   Nous injecterons un script **Bash** (via le `user_data` Terraform) qui agit comme un playbook Ansible local au démarrage de chaque instance.

### ☁️ Cloudflare : Le Vigile & L'Entrepôt
*   **Sécurité :** Bloque les attaques avant qu'elles ne touchent AWS (et ne coûtent de l'argent).
*   **Stockage (R2) :** Remplace AWS S3.
    *   *Avantage :* 0 $ de frais de sortie (Egress fees). Sur AWS, télécharger des images coûte cher. Sur Cloudflare R2, c'est gratuit.

---

## 3. Implémentation Étape par Étape

### Phase A : Le Réseau & FinOps (Le Socle)
*Le plus gros défi technique, mais la plus grosse économie.*

1.  **VPC Multi-AZ :** Création d'un réseau sur Paris (`eu-west-3`) avec 2 AZ.
2.  **L'Astuce NAT Instance :**
    *   Normalement, AWS vend des "NAT Gateways" (66$/mois) pour que les serveurs privés accèdent à internet.
    *   **Nous déployons 2 petites instances EC2 `t3.nano`** (une par zone).
    *   Nous les configurons en routeurs (`iptables -t nat -A POSTROUTING -j MASQUERADE`).
    *   **Coût :** ~8$/mois.
    *   **Terraform :** On configure les `aws_route_table` des sous-réseaux privés pour utiliser l'ID de ces instances comme passerelle `0.0.0.0/0`.

### Phase B : La Data (Le Coffre-fort)
*Les données ne doivent jamais être perdues.*

1.  **RDS PostgreSQL :**
    *   Déployé dans les sous-réseaux privés "Data".
    *   En **PROD** : `multi_az = true`. Une copie synchrone est faite dans l'autre zone.
    *   Security Group : N'accepte que le port 5432 venant des instances App.
2.  **ElastiCache Redis :**
    *   Stocke les sessions utilisateurs. Si une instance App meurt, l'utilisateur ne est pas déconnecté car sa session est dans Redis.
    *   Type : `cache.t3.micro` (Suffisant et pas cher).

### Phase C : L'Application (Le Moteur)
*Dockerisation pour la portabilité.*

1.  **L'Image Docker :**
    *   On construit une image pour le Backend (API) et une pour le Storefront (Next.js).
    *   On utilise **Caddy** dans le `docker-compose.yml` comme chef d'orchestre local.
2.  **Intégration R2 (Stockage Images) :**
    *   Dans Medusa, on installe le plugin `medusa-file-s3`.
    *   On le configure avec l'endpoint S3 de Cloudflare : `https://<account_id>.r2.cloudflarestorage.com`.
    *   Résultat : Quand l'admin upload une photo produit, elle part direct chez Cloudflare, pas sur le disque du serveur.

### Phase D : Le Scaling (L'Élasticité)

1.  **Launch Template :**
    *   C'est le "moule" des serveurs. Il contient le script de démarrage (`user_data`).
    *   Le script fait : `Install Docker` -> `Git Clone` -> `Docker Compose Up`.
2.  **Auto Scaling Group (ASG) :**
    *   Il surveille le CPU.
    *   Si CPU > 60% : Il crée une nouvelle instance à partir du moule.
    *   Si CPU < 40% : Il tue une instance.
3.  **Application Load Balancer (ALB) :**
    *   C'est le point d'entrée unique.
    *   L'ASG enregistre automatiquement les nouvelles instances dans l'ALB.

---

## 4. Stratégie FinOps (Comment on tient les 500$)

C'est ce qui vous donnera la note maximale.

### 1. Architecture NAT "Low-Cost"
*   **Gain :** ~58 $ / mois.
*   **Technique :** Remplacement des NAT Gateways managées par des instances EC2 `t3.nano` Linux configurées manuellement.

### 2. Le "Scheduler" Preprod
*   **Gain :** ~70 % sur la facture Preprod.
*   **Technique :**
    *   L'environnement de Preprod est identique à la Prod (Multi-AZ, RDS, ALB).
    *   **Mais** un script Terraform (`aws_autoscaling_schedule`) éteint tout (Desired Capacity = 0) tous les soirs à 19h et le rallume à 9h.
    *   On ne paie pas pour des serveurs qui dorment.

### 3. Cloudflare R2 vs S3
*   **Gain :** Variable (selon trafic), mais élimine le risque de dépassement "Data Transfer Out".
*   **Technique :** Utilisation du stockage objet Cloudflare qui ne facture pas la bande passante sortante.

### 4. Instances Spot en DEV
*   **Gain :** ~60-70% sur le compute Dev.
*   **Technique :** L'environnement de Dev utilise des instances "Spot" (enchères sur la capacité inutilisée d'AWS).

---

## 5. Guide de Survie : Commandes Utiles

### Initialiser le projet
```bash
# 1. Configurer les variables d'environnement AWS
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="secret..."

# 2. Bootstrap (Créer le bucket d'état S3 une seule fois)
./scripts/bootstrap.sh

# 3. Initialiser Terraform
cd terraform
terraform init
```

### Déployer la PROD
```bash
# Toujours vérifier avant de casser
terraform plan -var-file="envs/prod.tfvars"

# Appliquer
terraform apply -var-file="envs/prod.tfvars"
```

### Déployer la DEV (Low Cost)
```bash
# Changer de workspace
terraform workspace new dev || terraform workspace select dev

# Appliquer la config light
terraform apply -var-file="envs/dev.tfvars"
```

### Se connecter à une instance privée (Debug)
Comme les instances sont privées, on passe par le "Session Manager" (SSM) ou on utilise la NAT instance comme bastion (si configuré).
*Recommandé :* Utiliser AWS SSM (déjà installé sur Amazon Linux 2).
```bash
aws ssm start-session --target i-0123456789abcdef0
```

