# Rapport d'Analyse FinOps

**Projet :** GreenLeaf - Plateforme E-commerce Scalable sur AWS

**Auteurs :** Équipe GreenLeaf

**Date :** 06 Janvier 2026

**Version :** 1.0

---

## 1. Résumé Exécutif

Ce rapport présente l'analyse FinOps du projet GreenLeaf. Grâce à une stratégie d'optimisation agressive, **nous respectons le budget de 500$/mois** tout en garantissant une architecture Haute Disponibilité.

| Métrique | Valeur |
|:---------|:-------|
| **Coût Mensuel Estimé (Pay-As-You-Go)** | ~650 $ |
| **Coût Mensuel Optimisé** | **~405 $** |
| **Économie Réalisée** | **~38%** |
| **Budget Respecté** | ✅ Oui (<500$) |

**Les 4 leviers d'économie principaux :**
1. NAT Instance vs NAT Gateway (-60$/mois)
2. Cloudflare R2 vs S3 (-30$/mois estimé)
3. Scheduling Preprod (-65$/mois)
4. Instances Spot en DEV (-25$/mois)

---

## 2. Estimation Détaillée des Coûts

### 2.1. Environnement de PRODUCTION (24/7)

| Service | Composant | Coût Mensuel ($) | Hypothèses |
|:--------|:----------|:-----------------|:-----------|
| **EC2** | 2x t3.small (730h) | 30.66 | On-Demand, eu-west-3 |
| **ALB** | 1x Application LB | 18.40 | 730h + 10 LCU-hours |
| **RDS** | 1x db.t3.medium Multi-AZ | 138.70 | PostgreSQL, 730h |
| **ElastiCache** | 1x cache.t3.micro | 12.41 | Redis, 730h |
| **EBS** | 40 Go gp3 (EC2) | 3.60 | 2x 20Go |
| **NAT Instance** | 2x t3.nano | 7.59 | On-Demand, 730h |
| **Cloudflare R2** | 50 Go + 1M requêtes | 0.75 | Stockage média |
| **Divers** | Route53, CloudWatch | 10.00 | Estimation |
| **TOTAL PROD** | | **~222 $** | |

### 2.2. Environnement de PREPROD (Schedulé 50h/semaine)

| Service | Composant | Coût Mensuel ($) | Hypothèses |
|:--------|:----------|:-----------------|:-----------|
| **EC2** | 2x t3.small (~200h) | 8.40 | Schedulé L-V 9h-19h |
| **ALB** | 1x Application LB | 18.40 | 730h (toujours actif) |
| **RDS** | 1x db.t3.micro Single-AZ (~200h) | 10.22 | Arrêté la nuit |
| **ElastiCache** | 1x cache.t3.micro (~200h) | 3.40 | Arrêté la nuit |
| **NAT Instance** | 1x t3.nano | 3.80 | On-Demand |
| **TOTAL PREPROD** | | **~45 $** | |

> [!TIP]
> **Le Scheduling Preprod** permet d'économiser ~70% par rapport à un fonctionnement 24/7 (150$ → 45$).

### 2.3. Environnement de DEV (Low-Cost)

| Service | Composant | Coût Mensuel ($) | Hypothèses |
|:--------|:----------|:-----------------|:-----------|
| **EC2 Spot** | 1x t3.small | 6.00 | Instance Spot (-70%) |
| **EBS** | 20 Go gp3 | 1.80 | Stockage |
| **Docker DB** | PostgreSQL + Redis | 0.00 | Conteneurs locaux |
| **TOTAL DEV** | | **~8 $** | |

### 2.4. Synthèse Globale

| Environnement | Coût Mensuel |
|:--------------|:-------------|
| PRODUCTION | ~222 $ |
| PREPROD | ~45 $ |
| DEV | ~8 $ |
| **Réseau / Divers** | ~30 $ |
| **TOTAL** | **~305 $** |

---

## 3. Stratégies d'Optimisation Mises en Place

### 3.1. NAT Instance vs NAT Gateway

**Problème :** Les NAT Gateways AWS coûtent ~33$/mois chacune. Avec 2 AZ, cela fait 66$/mois juste pour le routage sortant.

**Solution :** Déploiement de 2 instances `t3.nano` configurées en routeur IP.

| Solution | Coût Mensuel | Économie |
|:---------|:-------------|:---------|
| NAT Gateway (x2) | 66 $ | - |
| NAT Instance (x2) | 8 $ | **-58 $/mois** |

**Configuration technique :**
```bash
#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

### 3.2. Cloudflare R2 vs AWS S3

**Problème :** AWS S3 facture le transfert sortant (Egress) à ~0.09$/Go. Pour un site e-commerce avec beaucoup d'images, cela peut exploser.

**Solution :** Utilisation de Cloudflare R2 qui offre **0$ de frais Egress**.

| Service | Stockage 50Go | Egress 500Go | Total |
|:--------|:--------------|:-------------|:------|
| AWS S3 | 1.15 $ | 45.00 $ | **46.15 $** |
| Cloudflare R2 | 0.75 $ | 0.00 $ | **0.75 $** |

**Économie : ~45$/mois** (selon trafic)

### 3.3. Scheduling de la Preprod

**Problème :** Faire tourner un environnement Preprod identique à la Prod 24/7 coûte ~150$/mois.

**Solution :** Utiliser `aws_autoscaling_schedule` pour éteindre les EC2 la nuit et le weekend.

```hcl
resource "aws_autoscaling_schedule" "preprod_shutdown" {
  scheduled_action_name  = "go-to-sleep"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 19 * * MON-FRI"  # 19h00 UTC
  autoscaling_group_name = module.app.asg_name
}

resource "aws_autoscaling_schedule" "preprod_wakeup" {
  scheduled_action_name  = "wake-up"
  min_size               = 2
  max_size               = 4
  desired_capacity       = 2
  recurrence             = "0 09 * * MON-FRI"  # 09h00 UTC
  autoscaling_group_name = module.app.asg_name
}
```

**Économie : ~105$/mois** (70% de réduction)

### 3.4. Instances Spot en DEV

**Problème :** Les instances On-Demand sont chères pour un environnement de développement.

**Solution :** Utilisation d'instances Spot (capacité inutilisée AWS à prix réduit).

| Type | Coût t3.small/mois |
|:-----|:-------------------|
| On-Demand | 15.33 $ |
| Spot | ~4.60 $ |

**Économie : ~70%**

### 3.5. Dimensionnement (Right-Sizing)

| Composant | Choix Initial | Choix Optimisé | Justification |
|:----------|:--------------|:---------------|:--------------|
| EC2 App | t3.medium | **t3.small** | Medusa consomme <1Go RAM |
| RDS | db.t3.medium | **db.t3.micro** (Preprod) | Trafic réduit en Preprod |
| Redis | cache.t3.small | **cache.t3.micro** | Suffisant pour sessions |

---

## 4. Recommandations pour le Futur

### 4.1. Savings Plans (Après 3 mois de production)

Une fois le trafic stabilisé, nous recommandons l'achat de **Compute Savings Plans** (1 an, No Upfront) :

| Service | Coût On-Demand | Coût Savings Plan | Économie |
|:--------|:---------------|:------------------|:---------|
| EC2 (2x t3.small) | 30.66 $ | 18.40 $ | **40%** |
| RDS (db.t3.medium) | 138.70 $ | 97.09 $ | **30%** |
| **TOTAL** | 169.36 $ | 115.49 $ | **~32%** |

> [!IMPORTANT]
> Ne pas acheter de Savings Plans avant d'avoir 3 mois de données Cost Explorer pour valider le dimensionnement.

### 4.2. Politiques de Cycle de Vie S3/R2

Pour les logs et backups anciens :
- **< 30 jours** : Stockage Standard
- **30-90 jours** : S3 Standard-IA / R2 Infrequent
- **> 90 jours** : S3 Glacier Deep Archive

### 4.3. Reserved Instances RDS

Pour la base de données de production (charge stable) :
- **RI 1 an No Upfront** : ~30% d'économie
- **RI 3 ans All Upfront** : ~50% d'économie (si budget disponible)

---

## 5. Mise en Place du Suivi Budgétaire

### 5.1. AWS Budgets

**Alerte configurée :**
- **Budget mensuel** : 500 $
- **Seuil 1** : 80% (400$) → Email d'avertissement
- **Seuil 2** : 100% (500$) → Email critique

### 5.2. Cost Explorer

**Filtres recommandés :**
- Par **Service** : Identifier les postes de coût majeurs
- Par **Tag** : Filtrer par environnement

### 5.3. Stratégie de Tagging

| Tag | Valeurs |
|:----|:--------|
| `Project` | `GreenLeaf` |
| `Environment` | `production`, `preprod`, `dev` |
| `Owner` | `devops-team` |
| `CostCenter` | `ecommerce` |

**Exemple Terraform :**
```hcl
default_tags {
  tags = {
    Project     = "GreenLeaf"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

---

## 6. Conclusion

L'architecture GreenLeaf démontre qu'il est possible de déployer une plateforme e-commerce **Haute Disponibilité** tout en respectant un budget de **500$/mois**.

**Les clés du succès FinOps :**
1. **Optimisation agressive** des composants (NAT Instance, Spot, R2)
2. **Scheduling intelligent** des environnements non-prod
3. **Monitoring continu** via AWS Budgets et Cost Explorer
4. **Architecture hybride** (AWS + Cloudflare) pour maximiser le rapport qualité/prix

---
