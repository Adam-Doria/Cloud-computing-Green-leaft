# Template : Rapport d'Analyse FinOps

**Projet :** GreenLeaf - Déploiement d'une Plateforme E-commerce Scalable sur AWS

**Auteurs :** [Noms des membres de l'équipe]

**Date :** [Date]

**Version :** 1.0

---

## 1. Résumé Exécutif (Executive Summary)

*Synthèse pour les décideurs de GreenLeaf. Présentez le coût mensuel estimé de l'architecture, les économies potentielles grâce à vos recommandations, et affirmez que le projet respecte les contraintes budgétaires.* 

**Coût Mensuel Estimé (Pay-As-You-Go) :** X.XX $
**Coût Mensuel Optimisé (avec recommandations) :** Y.YY $
**Économie Potentielle :** Z.ZZ % 

## 2. Estimation Détaillée des Coûts

*Utilisez l'AWS Pricing Calculator ou les données du Cost Explorer pour détailler le coût de chaque service. Un tableau est indispensable ici.*

| Service | Composant | Coût Mensuel Estimé ($) | Hypothèses de Calcul |
| :--- | :--- | :--- | :--- |
| EC2 | 2x t3.medium (730h/mois) | XX.XX | Instances à la demande, utilisation moyenne de 100% du temps. |
| ALB | 1x Application Load Balancer | XX.XX | 730h/mois + traitement de 100 Go de données. |
| RDS | 1x db.t3.medium Multi-AZ | XX.XX | Instance à la demande, 730h/mois. |
| ElastiCache | 1x cache.t3.small | XX.XX | Instance à la demande, 730h/mois. |
| S3 | Stockage + Requêtes | X.XX | 100 Go de stockage Standard, 1 million de requêtes GET. |
| CloudFront | Transfert de données | X.XX | 500 Go de transfert de données vers Internet. |
| **TOTAL** | | **XXX.XX** | |

## 3. Stratégies d'Optimisation des Coûts Mises en Place

*Décrivez les actions concrètes que vous avez réalisées pour maîtriser les coûts.* 

### 3.1. Dimensionnement (Right-Sizing)
*Expliquez comment vous avez choisi la taille des instances (EC2, RDS, ElastiCache). Si vous avez ajusté la taille en cours de projet, montrez les données (ex: métriques CloudWatch de CPU) qui ont justifié ce changement.*

### 3.2. Utilisation d'un CDN (CloudFront)
*Expliquez comment CloudFront réduit les coûts. Comparez le coût de 1 To de Data Transfer Out depuis S3/ALB vs. le coût du même To via CloudFront.*

### 3.3. Automatisation (Auto Scaling)
*Expliquez comment l'Auto Scaling permet d'éviter de payer pour des serveurs inutilisés pendant les heures creuses.*

### 3.4. Choix des Services Managés
*Justifiez le choix d'un service comme RDS par rapport à une solution auto-gérée sur EC2, en incluant le coût de la main-d'œuvre évitée (temps de patching, de backup, etc.) dans votre argumentation.*

## 4. Recommandations pour le Futur

*Proposez des actions pour réduire davantage les coûts à moyen et long terme.* 

### 4.1. Instances Réservées et Savings Plans
*C'est la partie la plus importante de cette section.* 

- **Analyse de l'existant :** Identifiez les charges de travail stables qui sont de bons candidats pour une réservation (ex: RDS, ElastiCache, 1 ou 2 instances EC2 de base).
- **Proposition chiffrée :** En utilisant l'AWS Pricing Calculator, simulez l'achat d'un **Savings Plan (Compute ou EC2 Instance)** ou d'**Instances Réservées** sur 1 an, sans paiement initial (No Upfront). 
- **Tableau comparatif :** 

| Service | Coût à la Demande ($) | Coût avec Savings Plan 1 an ($) | Économie (%) |
| :--- | :--- | :--- | :--- |
| EC2 (2 instances) | XX.XX | YY.YY | ZZ % |
| RDS (1 instance) | AA.AA | BB.BB | CC % |
| **TOTAL** | | | |

### 4.2. Politiques de Cycle de Vie S3
*Proposez de mettre en place des règles pour déplacer automatiquement les anciens fichiers (ex: logs, anciennes images) vers des classes de stockage moins chères comme S3 Standard-IA ou S3 Glacier.*

### 4.3. Planification de l'Arrêt des Environnements
*Suggérez d'automatiser l'arrêt des environnements de développement et de test en dehors des heures de bureau pour réaliser des économies significatives.*

## 5. Mise en Place du Suivi Budgétaire

*Décrivez les outils que vous avez mis en place pour que GreenLeaf puisse suivre ses dépenses.* 

- **AWS Budgets :** Montrez une capture d'écran ou décrivez l'alerte budgétaire que vous avez configurée (ex: alerte par e-mail lorsque 80% du budget de 500$ est atteint).
- **Cost Explorer :** Expliquez comment l'équipe de GreenLeaf peut utiliser le Cost Explorer pour visualiser la répartition des coûts par service.
- **Tagging :** Décrivez la stratégie de tags que vous avez mise en place (ex: `Projet:GreenLeaf`, `Environnement:Production`) pour filtrer les coûts.

---
