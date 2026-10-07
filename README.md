# 🚀 Enterprise Shell Scripting & DevOps Automation Toolkit

A curated collection of production-grade Bash scripts, SRE diagnostics, security baselines, and performance monitors ranging from foundational administration to advanced cloud and container operations.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20WSL-brightgreen.svg)]()

---

## 📚 Complete Script Catalog (1 – 50)

| # | Script Name | Level | Domain | Description |
|---|---|---|---|---|
| **01** | `01_beginner_system_report.sh` | Beginner | SysAdmin | Generates foundational system report (OS, kernel, CPU, disk, memory). |
| **02** | `02_intermediate_log_monitor.sh` | Intermediate | Monitoring | Real-time syslog/authlog log file anomaly monitor. |
| **03** | `03_system_report.sh` | Intermediate | SysAdmin | Comprehensive system audit and resource summary. |
| **04** | `04_log_monitor.sh` | Intermediate | Observability | Filtered log streaming with pattern alerting. |
| **05** | `05_backup_rotator.sh` | Intermediate | Storage | Automated directory compression and rolling backup retention. |
| **06** | `06_disk_space_alert.sh` | Intermediate | Storage | Filesystem capacity threshold monitoring and email/terminal alerting. |
| **07** | `07_user_account_manager.sh` | Intermediate | Security | Linux user and group provisioning, lockouts, and auditing. |
| **08** | `08_service_health_check.sh` | Intermediate | Reliability | Service watchdog and automated recovery daemon. |
| **09** | `09_ssl_cert_expiry_checker.sh` | Intermediate | Security | TLS/SSL certificate expiration date monitoring. |
| **10** | `10_network_port_scanner.sh` | Intermediate | Networking | TCP socket connectivity testing and host port enumeration. |
| **11** | `11_process_watchdog.sh` | Intermediate | Reliability | Runaway process CPU and memory resource enforcement. |
| **12** | `12_log_rotator_archiver.sh` | Intermediate | Storage | Gzip log rotation and archival strategy. |
| **13** | `13_database_backup_manager.sh` | Intermediate | Database | Database dump manager with SHA checksum validation. |
| **14** | `14_docker_cleanup_tool.sh` | Intermediate | Containers | Docker dangling container, volume, and image maintenance. |
| **15** | `15_file_integrity_checker.sh` | Intermediate | Security | SHA256 file fingerprinting for intrusion and tamper detection. |
| **16** | `16_website_uptime_monitor.sh` | Intermediate | Networking | HTTP status code and response latency health watchdog. |
| **17** | `17_git_repo_syncer.sh` | Intermediate | DevOps | Multi-repository batch status and sync utility. |
| **18** | `18_firewall_hardening_rules.sh` | Intermediate | Security | Baseline iptables / UFW firewall rule configuration. |
| **19** | `19_bulk_file_renamer.sh` | Intermediate | Utilities | Batch file normalization, sanitization, and regex renaming. |
| **20** | `20_memory_swap_monitor.sh` | Intermediate | Performance | RAM and swap space diagnostics and pressure warning. |
| **21** | `21_system_updates_auditor.sh` | Intermediate | SysAdmin | Package manager security patch auditing (APT/YUM). |
| **22** | `22_s3_cloud_backup_sync.sh` | Advanced | Cloud | Cloud object storage (AWS S3) synchronization. |
| **23** | `23_fail2ban_log_analyzer.sh` | Advanced | Security | SSH brute force analysis and IP ban forensics. |
| **24** | `24_cron_job_auditor.sh` | Advanced | Security | Scheduled cron job permissions and anomaly auditing. |
| **25** | `25_temp_file_cleaner.sh` | Intermediate | Maintenance | Safe /tmp and cache purging with file age filters. |
| **26** | `26_cpu_stress_benchmark.sh` | Advanced | Performance | Multi-core CPU load generation and thermal benchmarking. |
| **27** | `27_env_config_validator.sh` | Intermediate | DevOps | .env key-value integrity and secret template validation. |
| **28** | `28_ssl_tls_cipher_auditor.sh` | Advanced | Security | TLS cipher suite auditing and weak protocol rejection. |
| **29** | `29_git_branch_cleaner.sh` | Intermediate | DevOps | Automated pruning of stale merged local Git branches. |
| **30** | `30_k8s_pod_health_inspector.sh` | Advanced | Kubernetes | Pod restart anomaly, CrashLoopBackOff & OOM detector. |
| **31** | `31_redis_cache_benchmark.sh` | Intermediate | Database | Redis cache hit ratios, fragmentation, and latency metrics. |
| **32** | `32_nginx_log_analyzer.sh` | Intermediate | Observability | Web server access log parsing and top IP forensics. |
| **33** | `33_systemd_unit_auditor.sh` | Intermediate | SysAdmin | Systemd failed unit checks & boot latency (systemd-analyze). |
| **34** | `34_mysql_slow_query_parser.sh` | Advanced | Database | MySQL slow query log analysis and SLA violation detector. |
| **35** | `35_linux_security_baseline_scanner.sh` | Advanced | Security | CIS baseline hardening audit and permission scorecard. |
| **36** | `36_disk_io_latency_tracker.sh` | Advanced | Performance | Block device I/O latency, IOPS, and queue depth monitor. |
| **37** | `37_wireguard_vpn_manager.sh` | Intermediate | Networking | WireGuard peer handshake freshness and tunnel auditor. |
| **38** | `38_tar_gpg_encrypted_backup.sh` | Advanced | Security | AES-256 GPG symmetric encrypted backups with SHA256 hashing. |
| **39** | `39_tcp_syn_flood_detector.sh` | Advanced | Networking | TCP socket state analysis & SYN flood DDoS detection. |
| **40** | `40_ansible_playbook_syntax_linter.sh` | Intermediate | IaC | Ansible playbook best practices and secret exposure linter. |
| **41** | `41_aws_ec2_cost_optimizer.sh` | Advanced | Cloud | Cloud spend auditor: unattached EBS volumes & idle IPs. |
| **42** | `42_kernel_parameter_tuner.sh` | Advanced | Performance | Linux sysctl kernel tuning for socket backlog & memory. |
| **43** | `43_jwt_token_inspector.sh` | Intermediate | Security | RFC 7519 JSON Web Token decoder & expiration claim inspector. |
| **44** | `44_prometheus_metrics_exporter.sh` | Advanced | Observability | Native Bash Prometheus node metrics exposition format generator. |
| **45** | `45_zero_trust_ssh_key_auditor.sh` | Advanced | Security | Authorized_keys auditing for weak algorithms (DSA/RSA-1024). |
| **46** | `46_zfs_btrfs_snapshot_manager.sh` | Advanced | Storage | Atomic CoW filesystem snapshot retention manager. |
| **47** | `47_vault_secret_fetcher.sh` | Advanced | Security | HashiCorp Vault ephemeral in-memory secret lifecycle manager. |
| **48** | `48_kafka_topic_lag_checker.sh` | Advanced | Data | Apache Kafka consumer group lag & partition skew tracker. |
| **49** | `49_dns_propagation_checker.sh` | Intermediate | Networking | Multi-resolver global DNS propagation and latency auditor. |
| **50** | `50_automated_incident_postmortem_collector.sh` | SRE | Incident | Emergency diagnostic telemetry packager for root cause analysis. |

---

## 🤝 Contributing & License

Contributions, issues, and feature requests are welcome!
Licensed under the [MIT License](LICENSE).
