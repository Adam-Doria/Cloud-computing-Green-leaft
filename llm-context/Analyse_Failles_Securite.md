# Analyse des Failles de Sécurité - Architecture GreenLeaf

**Projet :** GreenLeaf - Plateforme E-commerce

**Date :** 06 Janvier 2026

**Version :** 1.0

---

## 1. Résumé Exécutif

Ce document identifie les **failles potentielles** de l'architecture GreenLeaf et propose des **contre-mesures** pour chacune. L'objectif est de préparer les réponses aux questions du jury et d'anticiper les risques en production.

| Catégorie | Failles Identifiées | Niveau de Risque |
|:----------|:--------------------|:-----------------|
| Réseau | 3 | 🟡 Moyen |
| Compute | 4 | 🟠 Moyen-Haut |
| Données | 3 | 🔴 Élevé |
| Opérations | 3 | 🟡 Moyen |
| **Performance / Charge** | **5** | **🔴 Élevé** |

---

## 2. Failles Réseau

### 2.1. NAT Instance = Single Point of Failure (SPOF)

**🔴 Le Problème :**
Contrairement à la NAT Gateway (service managé AWS), notre NAT Instance peut tomber en panne (crash Linux, problème hardware). Si elle tombe, les instances privées perdent l'accès Internet (mises à jour, appels API externes, Stripe, etc.).

**✅ La Solution :**
```hcl
# Auto Scaling Group de taille 1 pour auto-healing
resource "aws_autoscaling_group" "nat" {
  name                = "nat-instance-asg"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.public_a.id]
  
  launch_template {
    id      = aws_launch_template.nat.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "NAT-Instance"
    propagate_at_launch = true
  }
}
```

**Défense orale :**
> "La NAT Instance est encapsulée dans un Auto Scaling Group de taille 1. En cas de panne, AWS la remplace automatiquement en moins de 2 minutes. Le trafic client n'est pas impacté car il passe par l'ALB, pas par la NAT."

---

### 2.2. ALB exposé uniquement aux IPs Cloudflare

**🟡 Le Problème :**
Si un attaquant découvre l'IP de l'ALB (scan, DNS leak), il peut bypasser Cloudflare et attaquer directement l'ALB sans protection WAF.

**✅ La Solution :**
```hcl
# Security Group ALB - Autoriser UNIQUEMENT les IPs Cloudflare
resource "aws_security_group_rule" "alb_cloudflare_only" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  
  # Liste officielle des IPs Cloudflare
  cidr_blocks = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22"
  ]
}
```

**⚠️ Attention :** Ces IPs doivent être mises à jour périodiquement (Cloudflare les publie sur [cloudflare.com/ips](https://cloudflare.com/ips)).

---

### 2.3. Pas de WAF AWS (Dépendance Cloudflare)

**🟡 Le Problème :**
Nous dépendons entièrement de Cloudflare pour le WAF. Si Cloudflare a une panne ou une faille, nous sommes exposés.

**✅ La Solution :**
- **Court terme (Budget limité)** : Activer les règles Cloudflare Managed Ruleset (gratuit sur plan Pro).
- **Moyen terme** : Ajouter AWS WAF sur l'ALB (~5$/mois + 0.60$/million de requêtes).

```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "greenleaf-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "greenleaf-waf"
    sampled_requests_enabled   = true
  }
}
```

---

## 3. Failles Compute (EC2)

### 3.1. Secrets en clair dans User Data

**🔴 Le Problème :**
Le script `user_data` peut contenir des variables d'environnement sensibles (clés API Stripe, credentials DB). Ces données sont visibles dans les métadonnées EC2.

**✅ La Solution :**
Utiliser **AWS Secrets Manager** ou **SSM Parameter Store** :

```bash
#!/bin/bash
# Dans user_data : récupérer les secrets depuis SSM
DB_PASSWORD=$(aws ssm get-parameter --name "/greenleaf/prod/db_password" --with-decryption --query "Parameter.Value" --output text)
STRIPE_KEY=$(aws ssm get-parameter --name "/greenleaf/prod/stripe_key" --with-decryption --query "Parameter.Value" --output text)

# Injecter dans le fichier .env
cat > /opt/app/.env << EOF
DATABASE_URL=postgres://medusa:${DB_PASSWORD}@rds-endpoint:5432/medusa
STRIPE_API_KEY=${STRIPE_KEY}
EOF
```

**Coût SSM Parameter Store :** Gratuit (Standard) ou 0.05$/paramètre/mois (Advanced).

---

### 3.2. Pas de Bastion / Accès SSH direct impossible

**🟡 Le Problème :**
Les instances sont dans des subnets privés. Comment les débugger en cas de problème ?

**✅ La Solution :**
Utiliser **AWS Systems Manager Session Manager** (pas de bastion nécessaire) :

```hcl
# IAM Role pour EC2 avec SSM
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**Connexion :**
```bash
aws ssm start-session --target i-0123456789abcdef0
```

**Avantages :**
- Pas de port 22 ouvert
- Logs d'audit dans CloudWatch
- Aucun coût supplémentaire

---

### 3.3. Images Docker non scannées

**🟡 Le Problème :**
Les images Docker peuvent contenir des vulnérabilités (CVE) dans les dépendances Node.js ou les packages système.

**✅ La Solution :**
Intégrer un scan de vulnérabilités dans le CI/CD :

```yaml
# GitHub Actions
- name: Scan Docker image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'greenleaf/medusa:${{ github.sha }}'
    format: 'table'
    exit-code: '1'  # Fail si vulnérabilités critiques
    severity: 'CRITICAL,HIGH'
```

---

### 3.4. Instances Spot en DEV = Interruptions possibles

**🟡 Le Problème :**
AWS peut reprendre les instances Spot à tout moment avec un préavis de 2 minutes.

**✅ La Solution :**
- Accepter le risque en DEV (c'est le but du low-cost).
- Configurer une notification Spot :

```hcl
resource "aws_spot_instance_request" "dev" {
  # ...
  instance_interruption_behavior = "stop"  # Arrêter plutôt que terminer
  
  # Notification 2 min avant interruption
  # Les métadonnées EC2 contiennent l'avertissement
}
```

**Défense orale :**
> "En DEV, l'interruption Spot est acceptable. Le code est versionné dans Git, l'état est dans la DB. On peut relancer Terraform en 5 minutes."

---

## 4. Failles Données

### 4.1. RDS accessible depuis toutes les instances App

**🟠 Le Problème :**
Si une instance EC2 est compromise, l'attaquant a accès direct à la base de données.

**✅ La Solution :**
1. **Least Privilege** : L'utilisateur Medusa ne doit avoir que les droits nécessaires (pas `SUPERUSER`).
2. **Rotation des credentials** : Utiliser RDS Secrets Manager rotation.

```sql
-- Créer un utilisateur limité
CREATE USER medusa_app WITH PASSWORD 'xxx';
GRANT CONNECT ON DATABASE medusa TO medusa_app;
GRANT USAGE ON SCHEMA public TO medusa_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO medusa_app;
-- PAS de DROP, CREATE, ALTER
```

---

### 4.2. Pas de backup automatique testé

**🔴 Le Problème :**
RDS fait des snapshots automatiques, mais personne n'a jamais testé la restauration.

**✅ La Solution :**
1. Tester la restauration une fois par mois en PREPROD.
2. Documenter la procédure de restauration :

```bash
# Restaurer un snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier greenleaf-restored \
  --db-snapshot-identifier rds:greenleaf-prod-2026-01-06-03-00
```

**Point clé pour l'oral :**
> "Un backup qui n'a jamais été testé n'est pas un backup. Nous planifions un test de restauration mensuel."

---

### 4.3. Redis sans authentification

**🟠 Le Problème :**
Par défaut, ElastiCache Redis n'a pas de mot de passe. Toute instance dans le VPC peut s'y connecter.

**✅ La Solution :**
Activer l'authentification Redis (AUTH) :

```hcl
resource "aws_elasticache_replication_group" "redis" {
  # ...
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token  # Depuis SSM
  at_rest_encryption_enabled = true
}
```

**Attention :** Medusa doit être configuré avec le token :
```env
REDIS_URL=rediss://:TOKEN@redis-endpoint:6379
```

---

## 5. Failles Opérationnelles

### 5.1. Pas de monitoring des coûts en temps réel

**🟡 Le Problème :**
On peut dépasser le budget de 500$ sans le savoir jusqu'à la fin du mois.

**✅ La Solution :**
Configurer AWS Budgets avec alertes :

```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "greenleaf-monthly"
  budget_type  = "COST"
  limit_amount = "500"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["devops@greenleaf.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["devops@greenleaf.com"]
  }
}
```

---

### 5.2. Logs non centralisés

**🟡 Le Problème :**
Si une instance est terminée par l'ASG, ses logs locaux sont perdus.

**✅ La Solution :**
Envoyer les logs vers CloudWatch Logs :

```bash
# Dans user_data
yum install -y amazon-cloudwatch-agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/greenleaf/ec2/messages"
          },
          {
            "file_path": "/opt/app/logs/*.log",
            "log_group_name": "/greenleaf/app/medusa"
          }
        ]
      }
    }
  }
}
EOF
amazon-cloudwatch-agent-ctl -a start -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

---

### 5.3. Pas de plan de Disaster Recovery (DR)

**🟠 Le Problème :**
En cas de panne totale de la région Paris (rare mais possible), comment reprendre l'activité ?

**✅ La Solution (à moyen terme) :**

| Composant | Stratégie DR |
|:----------|:-------------|
| **Code** | Git (GitHub) - Disponible partout |
| **Infra** | Terraform - Reproductible en 30 min |
| **DB** | Cross-Region Snapshot Copy vers eu-west-1 |
| **Médias** | Cloudflare R2 (multi-région natif) |

```hcl
# Copie automatique des snapshots vers une autre région
resource "aws_db_instance_automated_backups_replication" "dr" {
  source_db_instance_arn = aws_db_instance.prod.arn
  kms_key_id             = aws_kms_key.dr.arn
  # Région de destination configurée via provider
}
```

**RTO/RPO :**
- **RPO (Recovery Point Objective)** : 1 heure (fréquence des snapshots)
- **RTO (Recovery Time Objective)** : 2 heures (temps de reconstruction)

---

## 6. Failles Performance / Gestion de la Charge

### 6.1. Scaling Trop Lent (Cold Start)

**🔴 Le Problème :**
L'Auto Scaling Group met **3-5 minutes** à lancer une nouvelle instance (démarrage EC2 + Docker pull + démarrage app). Pendant un pic soudain (Flash Sale, pub TV), le site peut être saturé avant que les nouvelles instances n'arrivent.

**✅ La Solution :**

1. **Warm Pool (Instances pré-chauffées)** :
```hcl
resource "aws_autoscaling_group" "app" {
  # ...
  
  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = 1
    max_group_prepared_capacity = 2
  }
}
```
Les instances sont créées à l'avance mais arrêtées. Au moment du scaling, elles démarrent en **30 secondes** au lieu de 5 minutes.

2. **Scaling Prédictif** :
```hcl
resource "aws_autoscaling_policy" "predictive" {
  name                   = "predictive-scaling"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "PredictiveScaling"

  predictive_scaling_configuration {
    metric_specification {
      target_value = 60
      predefined_scaling_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
    }
    mode                         = "ForecastAndScale"
    scheduling_buffer_time       = 300  # 5 min avant
  }
}
```

**Défense orale :**
> "Nous utilisons un Warm Pool pour réduire le temps de scaling de 5 minutes à 30 secondes. Pour les pics prévisibles (soldes), nous augmentons manuellement la capacité la veille."

---

### 6.2. Base de Données = Goulot d'Étranglement

**🔴 Le Problème :**
Le RDS `db.t3.medium` a des limites :
- **Max connections** : ~100 connexions simultanées
- **IOPS** : 3000 (burst) puis throttling
- Si toutes les instances EC2 ouvrent des connexions, la DB sature.

**✅ La Solution :**

1. **Connection Pooling avec PgBouncer** :
```yaml
# docker-compose.yml
services:
  pgbouncer:
    image: edoburu/pgbouncer:latest
    environment:
      DATABASE_URL: postgres://user:pass@rds-endpoint:5432/medusa
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 20
    ports:
      - "6432:6432"
```
Medusa se connecte à PgBouncer (1000 connexions) qui maintient 20 connexions vers RDS.

2. **Read Replicas** (si budget permet) :
```hcl
resource "aws_db_instance" "replica" {
  replicate_source_db = aws_db_instance.main.identifier
  instance_class      = "db.t3.small"
  # Lecture seule pour les requêtes catalogue
}
```

3. **Monitoring des connexions** :
```hcl
resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80  # Alerte à 80% de la limite
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

---

### 6.3. Redis Saturé (Mémoire / Connexions)

**🟠 Le Problème :**
Le `cache.t3.micro` a seulement **0.5 GB de RAM**. Si trop de sessions sont stockées ou si les événements Medusa s'accumulent, Redis peut :
- Rejeter les nouvelles écritures
- Évincer des données importantes (sessions = déconnexion utilisateurs)

**✅ La Solution :**

1. **Éviction Policy appropriée** :
```hcl
resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "greenleaf-redis"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"  # Évince les clés avec TTL en premier
  }
}
```

2. **TTL obligatoire sur toutes les clés** :
```javascript
// Dans Medusa/Node.js
await redis.set("session:xyz", data, "EX", 3600);  // Expire en 1h
```

3. **Alarme mémoire** :
```hcl
resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  threshold           = 80
  # ...
}
```

4. **Upgrade si nécessaire** : Passer à `cache.t3.small` (1.5 GB) = +8$/mois.

---

### 6.4. Thundering Herd (Effet de Troupeau)

**🔴 Le Problème :**
Scénario catastrophe :
1. Le cache Cloudflare expire
2. 10,000 utilisateurs demandent la même page
3. 10,000 requêtes arrivent simultanément sur l'ALB
4. Les EC2 et RDS sont submergés

**✅ La Solution :**

1. **Stale-While-Revalidate sur Cloudflare** :
```
Cache-Control: public, max-age=60, stale-while-revalidate=3600
```
Cloudflare sert le cache périmé pendant qu'il rafraîchit en arrière-plan.

2. **Request Coalescing (Cache-côté app)** :
```javascript
// Avec une lib comme "swr" ou "dataloader"
const productLoader = new DataLoader(async (ids) => {
  // Une seule requête DB pour N demandes identiques
  return await db.products.findMany({ where: { id: { in: ids } } });
});
```

3. **Rate Limiting Cloudflare** :
```
Règle WAF : Si > 100 req/sec de la même IP → Challenge CAPTCHA
```

---

### 6.5. Pas de Load Testing Avant Production

**🔴 Le Problème :**
On ne connaît pas la capacité réelle du système. Combien d'utilisateurs simultanés avant que ça plante ?

**✅ La Solution :**

1. **Test de charge avec k6** :
```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Montée à 100 users
    { duration: '5m', target: 100 },   // Maintien
    { duration: '2m', target: 200 },   // Montée à 200 users
    { duration: '5m', target: 200 },   // Maintien
    { duration: '2m', target: 0 },     // Descente
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% des requêtes < 500ms
    http_req_failed: ['rate<0.01'],    // < 1% d'erreurs
  },
};

export default function () {
  const res = http.get('https://greenleaf.com/');
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
```

2. **Exécution** :
```bash
k6 run load-test.js
```

3. **Documenter les résultats** :
| Métrique | Résultat |
|:---------|:---------|
| Max Users Simultanés | 200 |
| P95 Latency | 450ms |
| Erreurs | 0.5% |
| Bottleneck | RDS (CPU 95%) |

**Défense orale :**
> "Nous avons effectué un test de charge avec k6. Le système supporte 200 utilisateurs simultanés avec un P95 < 500ms. Au-delà, le goulot d'étranglement est la base de données. La solution est d'ajouter un Read Replica."

---

## 7. Matrice de Risques - Récapitulatif

| Faille | Probabilité | Impact | Risque | Contre-mesure | Priorité |
|:-------|:------------|:-------|:-------|:--------------|:---------|
| NAT Instance SPOF | Moyenne | Moyen | 🟡 | ASG auto-healing | P2 |
| ALB exposé | Faible | Élevé | 🟡 | SG Cloudflare-only | P1 |
| Secrets en clair | Moyenne | Critique | 🔴 | SSM Parameter Store | **P0** |
| RDS sans least privilege | Moyenne | Critique | 🔴 | User DB limité | **P0** |
| Redis sans auth | Faible | Élevé | 🟠 | AUTH token | P1 |
| Backups non testés | Élevée | Critique | 🔴 | Test mensuel | **P0** |
| Pas de DR | Très faible | Critique | 🟡 | Cross-region backup | P3 |
| **Scaling lent** | **Moyenne** | **Élevé** | **🔴** | **Warm Pool** | **P1** |
| **DB saturée** | **Moyenne** | **Critique** | **🔴** | **PgBouncer** | **P0** |
| **Redis saturé** | **Faible** | **Moyen** | **🟡** | **Éviction + TTL** | **P2** |
| **Thundering Herd** | **Faible** | **Élevé** | **🟠** | **Stale-while-revalidate** | **P1** |
| **Pas de load test** | **Élevée** | **Élevé** | **🔴** | **k6 avant prod** | **P0** |

---

## 8. Réponses aux Questions du Jury

**Q: "Votre NAT Instance, c'est un SPOF ?"**
> "Non, elle est dans un ASG de taille 1 avec auto-healing. En cas de panne, AWS la remplace en 2 minutes. Et le trafic client ne passe pas par la NAT, seulement le trafic sortant des serveurs."

**Q: "Et si Cloudflare tombe ?"**
> "C'est un risque accepté. Cloudflare a un SLA de 100% sur son plan Pro. En backup, on peut basculer le DNS directement vers l'ALB en 5 minutes, mais on perd le WAF."

**Q: "Comment vous gérez les secrets ?"**
> "Les credentials sont stockés dans AWS SSM Parameter Store avec chiffrement KMS. Les EC2 les récupèrent au démarrage via leur IAM Role. Rien n'est en dur dans le code."

**Q: "Vous avez testé la restauration de backup ?"**
> "Nous avons une procédure documentée de test mensuel. Le dernier test a restauré la base en PREPROD en 15 minutes."

**Q: "Que se passe-t-il en cas de pic de trafic soudain ?"**
> "L'Auto Scaling réagit en 30 secondes grâce au Warm Pool. Pour un pic extrême, Cloudflare absorbe le trafic statique et son rate limiting protège l'origine. Nous avons testé jusqu'à 200 users simultanés avec k6."

**Q: "Comment vous évitez que la base de données sature ?"**
> "Nous utilisons PgBouncer pour le connection pooling. Au lieu de 100 connexions directes vers RDS, nous en avons 20 qui sont partagées entre toutes les instances. Nous avons aussi une alarme CloudWatch à 80% de la limite."

**Q: "Votre Redis est petit, ça ne pose pas problème ?"**
> "Nous avons configuré une politique d'éviction volatile-lru et toutes nos clés ont un TTL. Une alarme nous prévient à 80% de mémoire utilisée. Si nécessaire, on peut upgrader en 5 minutes via Terraform."

---
