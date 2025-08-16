# Data Ingestion Orchestrators

This directory contains the orchestrator specifications that coordinate and manage the complex workflows within the FinPortIQ data ingestion component. Each orchestrator is responsible for specific coordination patterns and manages the interaction between agents, services, and external systems.

## Overview

The orchestration architecture implements the **Saga Pattern** with centralized coordination to manage distributed data ingestion workflows. The orchestrators ensure reliable execution, fault tolerance, and performance optimization across the entire data ingestion pipeline.

---

## Orchestration Architecture

### **Coordination Model**
- **Pattern**: Centralized Saga Pattern with persistent state management
- **Communication**: gRPC-based agent coordination with Kubernetes service discovery
- **Event-Driven**: Apache Kafka event bus for asynchronous coordination
- **State Management**: PostgreSQL backend with eventual consistency
- **Fault Tolerance**: Circuit breakers, retry strategies, and failure isolation

### **Workflow Execution**
- **Engine**: Kubernetes-native workflow execution using custom CRDs
- **Parallelization**: Intelligent step parallelization with resource optimization
- **Resource Management**: Dynamic resource allocation with auto-scaling
- **Monitoring**: Comprehensive step-level monitoring and performance tracking

---

## Orchestrator Services

### 1. API Manager Orchestrator (`base-data-ingestion-orchestrator-api-manager.yaml`)

**Type**: API Coordinator  
**Replicas**: 3 (High Availability)  
**Resource Profile**: 500m-2 CPU cores, 1-4Gi memory

#### **Core Responsibilities**
- **API Lifecycle Management**: Connection establishment, authentication renewal, health monitoring
- **Session Management**: Connection pooling with 10 sessions per API, 30-minute timeout
- **Rate Limit Compliance**: Global (1000/min) and per-API (100/min) rate limiting with burst capacity (200)
- **Error Handling**: Exponential backoff, circuit breakers, fallback API support

#### **Key Features**
- **Authentication Renewal**: Automatic token refresh and credential management
- **Degraded Mode Operations**: Graceful degradation when primary APIs are unavailable
- **Health Monitoring**: Continuous API endpoint health checks
- **Fallback Strategies**: Automatic failover to backup API sources

#### **Performance Targets**
- **Throughput**: 1,000 requests/minute global capacity
- **Availability**: 99.9% uptime with automatic failover
- **Latency**: Sub-second API coordination decisions
- **Scalability**: Auto-scaling based on API load patterns

---

### 2. Batch Manager Orchestrator (`base-data-ingestion-orchestrator-batch-manager.yaml`)

**Type**: Batch Coordinator  
**Replicas**: 2 (Resource Optimized)  
**Resource Profile**: 1-4 CPU cores, 2-8Gi memory

#### **Core Responsibilities**
- **Batch Processing**: 1GB maximum batch size with 5-minute timeout
- **Job Scheduling**: Kubernetes Jobs with dynamic resource allocation and priority queues
- **Dependency Management**: DAG execution with topological sort and failure isolation
- **Parallel Execution**: Up to 20 concurrent batches with resource optimization

#### **Key Features**
- **DAG Execution**: Complex workflow dependencies with topological sorting
- **Priority Queue**: Business priority-based job scheduling
- **Resource Allocation**: Dynamic CPU (500m-16 cores) and memory (1-64Gi) allocation
- **Failure Recovery**: Retry failed batches with exponential backoff

#### **Batch Processing Capabilities**
- **Maximum Batch Size**: 1GB per batch
- **Parallel Batches**: 20 concurrent processing streams
- **Resource Scaling**: Up to 16 CPU cores and 64Gi memory per job
- **Timeout Management**: 5-minute batch processing timeout

---

### 3. File Manager Orchestrator (`base-data-ingestion-orchestrator-file-manager.yaml`)

**Type**: File Coordinator  
**Replicas**: 2 (Storage Optimized)  
**Resource Profile**: 1-4 CPU cores, 2-8Gi memory

#### **Core Responsibilities**
- **File Processing**: Multi-protocol support (SFTP, FTP, S3, Azure Blob, GCS)
- **Directory Watching**: Pattern-based file monitoring with 5-minute polling
- **File Lifecycle**: Quarantine, archival, and cleanup automation
- **Parallel Downloads**: 10 concurrent downloads with 10MB chunk size

#### **Supported Protocols**
- **Cloud Storage**: AWS S3, Azure Blob Storage, Google Cloud Storage
- **Network Protocols**: SFTP, FTP with secure authentication
- **File Formats**: CSV, JSON, XML, Parquet with automatic detection

#### **Storage Management**
- **Temporary Storage**: 100Gi for active file processing
- **Archive Storage**: 1Ti for long-term file retention
- **Cleanup Automation**: 24-hour cleanup interval for temporary files
- **Integrity Verification**: Checksum validation for all file transfers

#### **File Processing Features**
- **Change Detection**: Timestamp and size-based file change monitoring
- **Pattern Matching**: Configurable file pattern watching (*.csv, *.json, etc.)
- **Parallel Processing**: 10 concurrent file download streams
- **Error Handling**: Quarantine failed files for manual review

---

### 4. Ingestion Manager Orchestrator (`base-data-ingestion-orchestrator-ingestion-manager.yaml`)

**Type**: Master Coordinator ⭐  
**Replicas**: 2 (High Availability with Leader Election)  
**Resource Profile**: 1-4 CPU cores, 2-8Gi memory, 10-50Gi storage

#### **Core Responsibilities**
- **Master Coordination**: Centralized orchestration of all ingestion workflows
- **Agent Management**: Coordination of 6 ingestion agents with health monitoring
- **Workflow Execution**: 5 workflow types with parallel execution and optimization
- **Event Processing**: Kafka-based event coordination with 100-message batches

#### **Agent Coordination** (6 Managed Agents)
1. **Data Collector** (3 instances) - Data collection, source connection
2. **Data Connector** (2 instances) - Authentication, connection pooling
3. **Data Converter** (4 instances) - Format conversion, schema inference
4. **Data Scheduler** (1 instance) - Schedule management, dependency resolution
5. **Data Merger** (2 instances) - Data consolidation, conflict resolution
6. **Data Fetch Retry** (2 instances) - Retry logic, failure recovery

#### **Workflow Types** (5 Supported Workflows)

##### **Standard Ingestion Workflow**
- **Steps**: Source validation → Connection → Collection → Conversion → Quality → Storage
- **Parallelization**: Data collection and format conversion
- **Timeout**: 2 hours with exponential backoff retry

##### **Secure API Ingestion Workflow**
- **Steps**: Security validation → Auth verification → Encrypted connection → Secure collection → Classification → Encrypted storage
- **Security Level**: High with mandatory audit trails
- **Timeout**: 3 hours with enhanced security checks

##### **Bulk File Ingestion Workflow**
- **Steps**: File discovery → Parallel processing → Format standardization → Consolidation → Batch validation
- **Parallel Workers**: 10 concurrent file processors
- **Chunk Size**: 100MB per processing unit
- **Timeout**: 6 hours for large file sets

##### **Real-time Stream Ingestion Workflow**
- **Steps**: Stream connection → Continuous processing → Real-time validation → Streaming storage
- **Continuous**: 24/7 operation with <1s latency target
- **Performance**: Sub-second processing latency

##### **Resilient Fetch Recovery Workflow**
- **Steps**: Failure analysis → Recovery strategy → Alternative sources → Data reconstruction → Validation
- **Fault Tolerance**: High with automatic fallback sources
- **Recovery**: Intelligent failure analysis and adaptive recovery

#### **State Management**
- **Persistence**: PostgreSQL backend with 30-day retention
- **Checkpoints**: 5-minute state checkpoint intervals
- **Consistency**: Eventual consistency with leader election
- **Recovery**: 15-minute RTO, 5-minute RPO targets

#### **Event Coordination**
- **Event Bus**: Apache Kafka with topic partitioning
- **Topics**: Workflow events (started/completed/failed), agent health
- **Processing**: 100-message batches with 30-second timeout
- **Reliability**: 3x replication factor with dead letter queue

#### **Performance Characteristics**
- **Concurrent Workflows**: 50 maximum concurrent executions
- **Auto-scaling**: 2-5 replicas based on workflow load
- **Connection Pooling**: 20 database, 100 agent connections
- **Caching**: 1GB workflow cache with intelligent TTL

---

### 5. Stream Manager Orchestrator (`base-data-ingestion-orchestrator-stream-manager.yaml`)

**Type**: Stream Coordinator  
**Replicas**: 3 (High Throughput)  
**Resource Profile**: 2-8 CPU cores, 4-16Gi memory

#### **Core Responsibilities**
- **Stream Management**: Multi-protocol streaming support with auto-scaling
- **Buffer Management**: 1GB buffer with 10-second flush intervals and compression
- **Backpressure Handling**: 80% threshold with drop-oldest strategy
- **Performance Optimization**: 10MB/s throughput with <100ms latency

#### **Supported Streaming Platforms**
- **Apache Kafka**: Enterprise-grade streaming with partition management
- **Amazon Kinesis**: AWS-native streaming with shard coordination
- **Google Pub/Sub**: GCP-native messaging with subscription management
- **RabbitMQ**: Message queue integration with advanced routing

#### **Stream Processing Features**
- **Concurrent Streams**: 100 maximum concurrent stream connections
- **Auto-scaling**: Dynamic scaling based on stream load
- **Monitoring**: Real-time stream health and performance monitoring
- **Checkpointing**: 30-second checkpoint intervals for fault tolerance

#### **Performance Targets**
- **Throughput**: 10MB/s sustained streaming throughput
- **Latency**: <100ms end-to-end stream processing
- **Availability**: 99.9% uptime with automatic failover
- **Buffer Management**: 1GB intelligent buffering with compression

---

## Integration Architecture

### **Inter-Orchestrator Communication**
- **Protocol**: gRPC with protocol buffers for type safety
- **Service Discovery**: Kubernetes DNS with health check integration
- **Load Balancing**: Round-robin with circuit breaker protection
- **Timeout Management**: Configurable timeouts per service interaction

### **External System Integration**

#### **Upstream Services**
- **Source Registry**: Data source catalog and configuration management
- **Policy Engine**: Governance and compliance policy enforcement
- **Scheduler Service**: Global scheduling coordination and optimization

#### **Downstream Services**
- **Data Quality**: Validation and quality scoring services
- **Feature Engineering**: Advanced data processing and transformation
- **Data Security**: Classification, encryption, and access control
- **Data Storage**: Persistent storage with multiple backend support

#### **Platform Services**
- **Event Coordination**: Platform-wide event management
- **Metadata Discovery**: Schema and lineage management
- **Monitoring**: Metrics collection and alerting integration

---

## Monitoring and Observability

### **Business Metrics**
- **Workflow Execution**: Total workflows, duration histograms, success rates
- **Agent Coordination**: Latency tracking, health monitoring, failure rates
- **Resource Utilization**: CPU, memory, storage utilization tracking
- **Performance**: Throughput, latency, and SLA compliance metrics

### **Technical Metrics**
- **System Health**: CPU, memory, network utilization
- **Event Processing**: Kafka lag, batch processing times
- **Database Performance**: Connection pool, query performance
- **Cache Efficiency**: Hit rates, eviction patterns

### **Health Checks**
- **Liveness**: 10-second interval with 5-second timeout
- **Readiness**: 5-second interval with 3-second timeout
- **Dependencies**: Database, Kafka, agent connectivity verification
- **Critical Path**: End-to-end workflow health validation

### **Alerting Configuration**

#### **Critical Alerts** (PagerDuty + Slack)
- Orchestrator service down (1-minute threshold)
- Workflow failure rate >10% (2-minute threshold)
- Agent coordination failures >5% (3-minute threshold)

#### **Warning Alerts** (Slack + Email)
- Workflow queue size >500 (5-minute threshold)
- Resource utilization >80% (10-minute threshold)
- Stream processing lag (configurable thresholds)

---

## Security and Compliance

### **Access Control**
- **RBAC**: Kubernetes role-based access control
- **Service Accounts**: Dedicated service accounts per orchestrator
- **Network Policies**: Namespace-based network segmentation
- **API Permissions**: Fine-grained API access controls

### **Data Security**
- **Encryption**: TLS 1.3 in transit, AES-256 at rest
- **Secret Management**: Kubernetes secrets with external rotation
- **Audit Logging**: Comprehensive activity logging with 90-day retention
- **Compliance**: SOX, GDPR, PCI DSS compliance support

### **Network Security**
- **Ingress Control**: Restricted ingress from monitoring namespaces
- **Egress Control**: Limited egress to required platform services
- **Port Management**: Specific port allowlists (8080, 9090, 5432, 9092)
- **TLS Enforcement**: Mandatory TLS for all external communications

---

## Disaster Recovery and High Availability

### **Backup Strategy**
- **State Backup**: Hourly PostgreSQL state backups with 7-day retention
- **Configuration Backup**: Daily configuration backups with version control
- **Cross-Region**: S3-based backup storage with cross-region replication

### **Recovery Procedures**
- **RTO Target**: 15-minute recovery time objective
- **RPO Target**: 5-minute recovery point objective
- **Automated Recovery**: Scripted recovery with validation steps
- **Failover**: Multi-AZ deployment with leader election

### **High Availability Design**
- **Leader Election**: Kubernetes-native leader election for singletons
- **Blue-Green Deployment**: Zero-downtime deployments
- **Circuit Breakers**: Automatic failure isolation and recovery
- **Multi-AZ**: Cross-availability zone deployment for resilience

---

## Performance Optimization

### **Resource Management**
- **Auto-scaling**: HPA based on CPU, memory, and custom metrics
- **Connection Pooling**: Optimized database and service connection pools
- **Caching Strategy**: Multi-level caching with intelligent TTL
- **Batch Processing**: Optimized batch sizes and processing windows

### **Performance Targets**

#### **Throughput Capabilities**
- **API Coordination**: 1,000 API calls/minute
- **Batch Processing**: 20 concurrent batches, 1GB each
- **File Processing**: 10 concurrent downloads, 10MB chunks
- **Stream Processing**: 10MB/s sustained throughput
- **Workflow Execution**: 50 concurrent complex workflows

#### **Latency Requirements**
- **API Coordination**: <1s decision latency
- **Batch Scheduling**: <5s job scheduling latency
- **File Discovery**: <30s file system scanning
- **Stream Processing**: <100ms stream processing latency
- **Workflow Coordination**: <2s step coordination latency

---

## Cost Optimization

### **Resource Efficiency**
- **Dynamic Scaling**: Demand-based replica scaling
- **Resource Right-sizing**: Optimized CPU and memory allocation
- **Storage Optimization**: Intelligent data lifecycle management
- **Network Optimization**: Reduced cross-AZ data transfer

### **Operational Efficiency**
- **Workflow Optimization**: Parallel execution with dependency optimization
- **Batch Consolidation**: Efficient batch size optimization
- **Connection Reuse**: Persistent connection pooling
- **Caching Strategy**: Reduced redundant operations

---

## Development and Operations

### **Development Workflow**
1. **Orchestrator Design**: CRD-based orchestrator specification
2. **Testing**: Comprehensive unit and integration testing
3. **Deployment**: Kubernetes-native deployment with GitOps
4. **Monitoring**: Real-time performance and health monitoring
5. **Optimization**: Continuous performance tuning

### **Operational Procedures**
1. **Health Monitoring**: Continuous health check validation
2. **Performance Tuning**: Regular performance optimization
3. **Capacity Planning**: Proactive resource scaling
4. **Incident Response**: Automated alerting and escalation
5. **Maintenance**: Scheduled maintenance with zero downtime

### **Troubleshooting Guide**
- **Workflow Failures**: Step-by-step workflow debugging
- **Agent Coordination**: Inter-service communication diagnostics
- **Performance Issues**: Resource utilization analysis
- **Event Processing**: Kafka lag and processing analysis
- **State Management**: Database connectivity and consistency checks

---

*This orchestration layer provides enterprise-grade coordination and management for complex financial data ingestion workflows, ensuring reliability, performance, and compliance in distributed microservices environments.*