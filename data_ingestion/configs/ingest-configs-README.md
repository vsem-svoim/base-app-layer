# Data Ingestion Configuration Files

This directory contains the configuration files that define the operational policies, authentication templates, format specifications, and source mappings for the FinPortIQ data ingestion component.

## Overview

The configuration system provides a declarative approach to managing complex data ingestion requirements across heterogeneous financial data sources. Each configuration file is structured as a Kubernetes Custom Resource Definition (CRD) under the `base.io/v1` API version.

---

## Configuration Files

### 1. Authentication Templates (`base-data-ingestion-config-authentication-templates.yaml`)

**Purpose**: Comprehensive authentication method templates for secure data source connections.

**Key Features**:
- **OAuth 2.0 Flows**: Client credentials, authorization code, device code with automatic token refresh
- **JWT Verification**: RS256, HS256, ES256 with configurable validation rules
- **API Key Management**: Header, query parameter, bearer token with rotation policies
- **Certificate Authentication**: Mutual TLS, client certificates with validation chains
- **Enterprise Integration**: SAML 2.0, LDAP/Active Directory, database authentication
- **Cloud Provider Auth**: AWS IAM roles, Azure service principals, GCP service accounts
- **Message Queue Auth**: Kafka SASL/SSL, RabbitMQ TLS
- **Custom Methods**: HMAC signatures, token exchange patterns

**Security Features**:
- Automatic credential rotation (30-90 day cycles)
- Encryption at rest (AES-256)
- Compliance frameworks (PCI DSS, SOX, GDPR)
- Comprehensive audit logging
- Certificate expiry monitoring

**Lines**: 539 lines
**Template Count**: 50+ authentication templates
**Compliance**: Enterprise security standards compliant

---

### 2. Format Specifications (`base-data-ingestion-config-format-specifications.yaml`)

**Purpose**: Detailed specifications for handling diverse data formats with validation and conversion rules.

**Supported Formats**:
- **Text Formats**: JSON, CSV, TSV, XML, fixed-width, log formats
- **Binary Formats**: Parquet, Avro, ORC with compression support
- **Spreadsheet Formats**: Excel XLSX/XLS, Google Sheets
- **Financial Formats**: SWIFT MT messages, ISO 20022 XML, FIX protocol
- **Document Formats**: PDF, TIFF with OCR and text extraction
- **Database Formats**: SQL dumps, proprietary export formats

**Key Capabilities**:
- **Schema Inference**: AI-powered automatic schema detection
- **Format Detection**: Magic number and content analysis
- **Validation Rules**: Syntax, structure, and business rule validation
- **Conversion Priorities**: Standardization to optimal formats (Parquet, Avro)
- **Performance Optimization**: Streaming thresholds, parallel processing, caching

**Quality Controls**:
- Data type validation (numeric, temporal, categorical)
- Business validation (financial data rules)
- Compression and encoding support
- Error handling strategies (skip, quarantine, retry)

**Lines**: 571 lines
**Format Count**: 25+ format specifications
**Processing**: Up to 8 parallel threads, 2GB memory limit

---

### 3. Ingestion Policies (`base-data-ingestion-config-ingestion-policies.yaml`)

**Purpose**: Comprehensive governance policies for data quality, security, compliance, and operational controls.

**Policy Categories**:

#### **Data Quality Policies**
- **Completeness**: 95% minimum completeness threshold with quarantine actions
- **Accuracy**: Schema validation, range checks, format compliance
- **Consistency**: Cross-reference validation, temporal consistency, referential integrity
- **Timeliness**: SLA enforcement (5m-4h based on priority), staleness detection

#### **Security & Privacy Policies**
- **Data Classification**: Automatic PII detection with 4-tier classification (public, internal, confidential, restricted)
- **Access Control**: RBAC enforcement, IP restrictions, service account validation
- **Encryption**: TLS 1.2+ for transit, AES-256 for rest, field-level encryption for sensitive data

#### **Compliance Policies**
- **GDPR**: Personal data handling, consent management, data subject rights
- **SOX**: Financial reporting controls, audit trails, segregation of duties
- **PCI DSS**: Cardholder data protection, security controls, compliance validation

#### **Performance Policies**
- **Throughput Management**: Rate limiting (10K req/min), resource allocation, concurrent processing
- **Quality Gates**: Bronze/Silver/Gold data promotion with blocking enforcement

#### **Data Lifecycle Policies**
- **Retention**: 3-10 year retention by data type, automatic archival after 2 years
- **Versioning**: Change tracking, rollback capabilities, approval workflows

**Lines**: 479 lines
**Policy Count**: 15+ comprehensive policy categories
**Enforcement**: Real-time evaluation with automatic violation handling

---

### 4. Source Mappings (`base-data-ingestion-config-source-mappings.yaml`)

**Purpose**: Detailed mapping and configuration of financial data sources with SLA requirements and integration points.

**Source Categories**:

#### **Financial Data Sources**
- **Market Data Providers**: Bloomberg API, Reuters Eikon, NYSE Cloud, NASDAQ Data Link
- **Alternative Data**: Social sentiment, economic indicators, satellite imagery
- **SLA Requirements**: 99.5-99.99% availability, <200ms-1s latency, throughput limits

#### **Database Sources**
- **Internal**: Portfolio management (PostgreSQL), Risk management (MySQL), Analytics (MongoDB)
- **External**: Vendor data warehouse (Oracle) with daily synchronization
- **Connection Pooling**: Optimized pool sizes, SSL requirements, timeout configurations

#### **File-based Sources**
- **Cloud Storage**: S3 reports, Azure Blob research data, GCS backups
- **SFTP Sources**: Prime brokerage, custodian data with daily collection schedules
- **Format Support**: CSV, Excel, PDF, Parquet, compressed formats

#### **Streaming Sources**
- **Message Queues**: Kafka market data (1M msg/sec), RabbitMQ orders, Kinesis audit logs
- **Real-time Processing**: <10ms latency, high availability, automatic failover

**Integration Features**:
- **Priority Mapping**: Critical, high, medium, low priority sources
- **Collection Strategies**: Real-time (<100ms), batch (10K records), scheduled (UTC timezone)
- **Quality Rules**: Data validation, compliance checks, downstream service integration
- **Monitoring**: Health checks, SLA tracking, automated alerting

**Lines**: 565 lines
**Source Count**: 25+ configured data sources
**Throughput**: Up to 1M messages/second for real-time streams

---

## Technical Architecture

### **Configuration Management**
- **API Version**: `base.io/v1` Kubernetes CRDs
- **Namespace**: `base-ingestion` for isolation
- **Labels**: Standardized labeling for component identification
- **Validation**: Schema validation with business rule enforcement

### **Integration Points**
- **Policy Engine**: Real-time policy evaluation service
- **Event Coordination**: Event-driven architecture for configuration changes
- **Audit System**: Comprehensive logging and compliance tracking
- **Monitoring**: Prometheus metrics, alert management, SLA tracking

### **Security Model**
- **Credential Management**: HashiCorp Vault integration
- **Encryption**: End-to-end encryption with key rotation
- **Access Control**: RBAC with principle of least privilege
- **Compliance**: Multiple regulatory framework support

---

## Usage Patterns

### **Development Workflow**
1. **Source Registration**: Add new source to source mappings
2. **Authentication Setup**: Configure authentication templates
3. **Format Definition**: Specify format handling rules
4. **Policy Assignment**: Apply governance policies
5. **Testing**: Validate configuration with test data

### **Operational Management**
1. **Policy Updates**: Version-controlled policy changes
2. **Source Monitoring**: SLA compliance tracking
3. **Security Reviews**: Regular authentication audit
4. **Performance Tuning**: Throughput optimization

### **Compliance Management**
1. **Policy Enforcement**: Automated compliance checking
2. **Audit Reporting**: Regular compliance reports
3. **Violation Handling**: Automated remediation workflows
4. **Documentation**: Comprehensive audit trails

---

## Performance Characteristics

### **Throughput Capacity**
- **API Sources**: Up to 20K requests/minute per source
- **Database Sources**: Connection pooling for optimal performance
- **File Sources**: Parallel processing with configurable workers
- **Streaming Sources**: Real-time processing up to 1M messages/second

### **Latency Requirements**
- **Real-time Data**: <100ms end-to-end latency
- **Critical Sources**: <500ms SLA
- **Batch Processing**: Configurable batch sizes and timeouts
- **Quality Validation**: Real-time validation without blocking

### **Resource Allocation**
- **Memory**: 2-8GB per processing job
- **CPU**: 1-8 cores based on complexity
- **Storage**: Temporary storage up to 100GB
- **Network**: Optimized for financial data patterns

---

## Security and Compliance

### **Data Protection**
- **Classification**: Automatic PII and sensitive data detection
- **Encryption**: AES-256 encryption at rest, TLS 1.2+ in transit
- **Masking**: Configurable field-level masking for sensitive data
- **Retention**: Policy-driven data lifecycle management

### **Access Control**
- **Authentication**: Multi-method authentication support
- **Authorization**: Fine-grained RBAC permissions
- **Audit Logging**: Comprehensive activity tracking
- **Network Security**: IP restrictions, service account controls

### **Regulatory Compliance**
- **GDPR**: Personal data protection and subject rights
- **SOX**: Financial reporting and audit controls
- **PCI DSS**: Payment card data security
- **Industry Standards**: Financial services regulatory compliance

---

## Monitoring and Observability

### **Health Monitoring**
- **Source Availability**: Real-time health checks
- **SLA Tracking**: Performance metrics and compliance
- **Quality Metrics**: Data validation success rates
- **Error Rates**: Failure detection and alerting

### **Alerting Configuration**
- **Critical Alerts**: PagerDuty integration for immediate response
- **Warning Alerts**: Slack notifications for proactive management
- **Info Alerts**: Email notifications for routine events
- **Escalation**: Automated escalation procedures

### **Performance Metrics**
- **Throughput**: Messages/requests per second
- **Latency**: End-to-end processing time
- **Success Rates**: Data validation and processing success
- **Resource Utilization**: CPU, memory, and storage usage

---

## Configuration Management Best Practices

### **Version Control**
- All configuration files are version controlled
- Change approval workflows for production updates
- Rollback capabilities for failed deployments
- Testing requirements before production promotion

### **Environment Management**
- Development, staging, and production configurations
- Environment-specific overrides and parameterization
- Secure credential management across environments
- Consistent deployment procedures

### **Documentation Standards**
- Comprehensive inline documentation
- Change logs for policy updates
- Integration guides for new sources
- Troubleshooting procedures and runbooks

---

*This configuration system enables enterprise-grade financial data ingestion with comprehensive governance, security, and operational controls suitable for regulated financial services environments.*