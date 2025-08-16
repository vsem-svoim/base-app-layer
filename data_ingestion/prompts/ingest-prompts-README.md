# Data Ingestion AI Agent Prompts

This directory contains the AI prompt templates that guide the intelligent decision-making capabilities of each data ingestion agent. These prompts serve as operational guidelines, enabling agents to make autonomous, context-aware decisions for complex data ingestion scenarios.

## Overview

The prompt architecture implements **AI-driven operational intelligence** where each agent uses sophisticated prompts to analyze situations, make decisions, and optimize performance. These prompts combine domain expertise, operational best practices, and adaptive learning to create intelligent autonomous agents.

---

## AI Agent Prompts

### 1. Data Collector Agent Prompt (`base-ingest-prompt-collector.md`)

**Agent Role**: Intelligent Data Acquisition Specialist  
**Lines**: 352 lines of comprehensive operational guidance  
**AI Capability**: Autonomous collection strategy optimization

#### **Core Intelligence Areas**

**Performance Optimization**
- **Throughput Targets**: 100GB/hour per agent instance
- **Success Rate**: >99% collection reliability
- **Resource Efficiency**: CPU <70%, Memory <80% utilization
- **Error Rate**: <1% with automatic recovery

**Source Intelligence**
- **Source Classification**: API, Database, File, Streaming, Real-time feeds
- **Data Characteristics**: Volume, Velocity, Variety, Veracity analysis
- **Technical Assessment**: Authentication, rate limits, connection pooling needs
- **Strategy Selection**: High-volume batch, Real-time API, Financial market-aware

**Adaptive Optimization**
```python
# Example AI Decision Logic
def optimize_collection_performance(source_metrics):
    if source_metrics.throughput < target_throughput:
        if source_metrics.cpu_utilization < 70%:
            increase_worker_threads()
            increase_connection_pool_size()
        else:
            request_additional_replicas()
```

**Quality Intelligence**
- **Real-time Quality Gates**: Format validation, completeness checks, consistency validation
- **Intelligent Sampling**: Systematic, stratified, reservoir, time-based sampling
- **Business Impact**: Revenue-affecting processes prioritization

#### **Advanced Capabilities**

**Security & Compliance Intelligence**
- **PII Detection**: Real-time sensitive data pattern recognition
- **Compliance Adaptation**: GDPR, SOX, PCI DSS, FINRA compliance awareness
- **Risk Assessment**: Data classification and protection strategies

**Integration Coordination**
- **Agent Collaboration**: Smart handoff to converter, quality feedback loops
- **Resource Management**: Dynamic allocation based on workload forecasting
- **Emergency Response**: Disaster recovery, degraded mode operations

---

### 2. Data Connector Agent Prompt (`base-ingest-prompt-connector.md`)

**Agent Role**: Connection Lifecycle & Authentication Manager  
**Lines**: 159 lines of connection intelligence  
**AI Capability**: Autonomous connection optimization

#### **Core Intelligence Areas**

**Authentication Strategy Intelligence**
- **Method Selection**: OAuth2, JWT, API Keys, Certificate-based, SAML
- **Lifecycle Management**: Token refresh, certificate rotation, key validation
- **Security Optimization**: mTLS implementation, cipher suite selection

**Connection Pool Optimization**
- **Dynamic Sizing**: Load pattern-based pool sizing
- **Performance Tuning**: Keep-alive optimization, connection reuse strategies
- **Health Monitoring**: Continuous validation and proactive replacement

**Integration Strategy Matrix**
| Source Type | Auth Method | Pool Size | Timeout | Security Level |
|-------------|-------------|-----------|---------|----------------|
| REST API | OAuth2 | 10-25 | 30s | TLS 1.3 |
| Database | Certificate | 5-15 | 60s | mTLS + Encryption |
| Enterprise | SAML | 15-30 | 45s | SSO + Audit |

#### **Resilience Patterns**
- **Circuit Breaker**: Failure threshold configuration with half-open testing
- **Retry Mechanisms**: Exponential backoff for transient failures
- **Health Monitoring**: Proactive connection replacement

---

### 3. Data Converter Agent Prompt (`base-ingest-prompt-converter.md`)

**Agent Role**: Format Standardization & Schema Transformation Specialist  
**Lines**: 192 lines of conversion intelligence  
**AI Capability**: Autonomous format optimization and schema inference

#### **Core Intelligence Areas**

**Format Detection & Analysis**
- **Format Recognition**: 15+ formats including CSV, JSON, XML, Parquet, Avro, Excel
- **Schema Inference**: Automatic data type detection with 95% confidence threshold
- **Encoding Detection**: Character encoding normalization
- **Performance Assessment**: Volume, complexity, quality analysis

**Conversion Strategy Development**
- **Algorithm Selection**: Streaming vs batch based on data volume
- **Performance Optimization**: Parallel processing, memory management
- **Quality Assurance**: Integrity validation, accuracy metrics

**Conversion Strategy Matrix**
| Input Format | Output Format | Strategy | Throughput | Memory Usage |
|--------------|---------------|----------|------------|--------------|
| CSV | JSON | Stream Parse | 50MB/s | Low |
| XML | Avro | DOM + Schema | 20MB/s | High |
| Excel | Parquet | Sheet Extract | 30MB/s | Medium |

#### **Advanced Capabilities**

**Schema Inference Intelligence**
- **Statistical Analysis**: Data type frequency, pattern recognition
- **ML Enhancement**: Historical patterns, supervised learning
- **Validation**: Business rule checking, iterative refinement

**Error Handling & Recovery**
- **Error Classification**: Syntax, semantic, resource, system errors
- **Recovery Strategies**: Skip and continue, default substitution, manual intervention
- **Quality Reporting**: Detailed logs, success rate trending

---

### 4. Data Merger Agent Prompt (`base-ingest-prompt-merger.md`)

**Agent Role**: Multi-Source Data Consolidation & Conflict Resolution Specialist  
**Lines**: 214 lines of merge intelligence  
**AI Capability**: Autonomous conflict resolution and data consolidation

#### **Core Intelligence Areas**

**Multi-Source Analysis Intelligence**
- **Schema Alignment**: Common field identification, structural similarity analysis
- **Data Overlap Assessment**: Duplicate detection, information overlap analysis
- **Quality Variance**: Cross-source quality assessment and normalization

**Conflict Resolution Strategies**
- **Last Write Wins**: Timestamp-based precedence for conflicting values
- **Weighted Average**: Source reliability-based calculation
- **Custom Logic**: Business rule application for domain-specific resolution

**Merge Strategy Matrix**
| Data Pattern | Merge Strategy | Conflict Resolution | Performance | Quality Impact |
|--------------|----------------|-------------------|-------------|----------------|
| High Overlap | Fuzzy Match + Dedup | Weighted Average | Medium | High |
| Time Series | Temporal Align | Last Write Wins | High | Medium |
| Master Data | Rule-Based | Business Logic | Low | Very High |

#### **Advanced Capabilities**

**Deduplication Intelligence**
- **Exact Match**: Hash-based comparison, checksum validation
- **Fuzzy Match**: Edit distance algorithms, phonetic matching
- **Probabilistic**: Fellegi-Sunter algorithm, Bayesian inference

**Performance Optimization**
- **Memory Management**: Streaming processing, external sorting
- **Parallel Processing**: Data partitioning, load balancing
- **Quality Assurance**: Validation frameworks, lineage tracking

---

### 5. Data Fetch Retry Agent Prompt (`base-ingest-prompt-retry.md`)

**Agent Role**: Resilience & Error Handling Specialist  
**Lines**: 153 lines of recovery intelligence  
**AI Capability**: Autonomous failure analysis and recovery optimization

#### **Core Intelligence Areas**

**Failure Classification Intelligence**
- **Transient Failures**: Network timeouts, service unavailability, rate limiting
- **Persistent Failures**: Authentication errors, configuration issues
- **Systematic Failures**: Infrastructure problems, cascading failures

**Retry Strategy Selection**
- **Exponential Backoff**: Base delay calculation with jitter implementation
- **Circuit Breaker**: Failure threshold configuration with fallback mechanisms
- **Linear Backoff**: Fixed increment delays for predictable patterns

**Decision Matrix**
| Failure Type | Strategy | Max Retries | Base Delay | Success Rate |
|--------------|----------|-------------|------------|--------------|
| Network Timeout | Exponential Backoff | 5 | 1s | 85% |
| Rate Limiting | Linear Backoff | 10 | 60s | 95% |
| Auth Failure | Credential Refresh | 2 | 0s | 70% |

#### **Advanced Capabilities**

**Recovery Strategy Development**
- **Fallback Sources**: Alternative source identification and validation
- **Partial Recovery**: Data segment identification, reconstruction algorithms
- **Dead Letter Queue**: Failed request categorization, batch processing

**Monitoring & Learning**
- **Success Rate Tracking**: Retry effectiveness monitoring
- **Pattern Recognition**: Recurring failure identification
- **Cost Analysis**: Resource utilization optimization

---

### 6. Data Scheduler Agent Prompt (`base-ingest-prompt-scheduler.md`)

**Agent Role**: Timing Coordination & Workflow Scheduling Specialist  
**Lines**: 119 lines of scheduling intelligence  
**AI Capability**: Autonomous schedule optimization and resource coordination

#### **Core Intelligence Areas**

**Schedule Pattern Analysis**
- **Schedule Types**: Cron-based, interval-based, event-driven, dependency-based
- **Business Constraints**: Business hours, maintenance windows, peak periods
- **Source Characteristics**: Update frequencies, availability patterns
- **Dependency Mapping**: Upstream/downstream system dependencies

**Optimization Strategy Development**
- **Temporal Optimization**: Collection timing based on source patterns
- **Resource Coordination**: CPU, memory, network bandwidth optimization
- **Dependency Management**: Critical path analysis, cascade failure prevention

#### **Advanced Capabilities**

**Resilience & Recovery Planning**
- **Failure Detection**: Automatic rescheduling capabilities
- **Schedule Drift**: Detection and correction mechanisms
- **Resource Exhaustion**: Prevention and recovery strategies

**Monitoring & Adaptation**
- **Historical Analysis**: Performance-based schedule optimization
- **Real-time Monitoring**: Dynamic adjustment capabilities
- **Business Correlation**: Schedule effectiveness measurement

---

## AI Intelligence Architecture

### **Autonomous Decision Making**
Each prompt enables agents to:
- **Analyze Complex Scenarios**: Multi-dimensional situation assessment
- **Make Contextual Decisions**: Business and technical context awareness
- **Optimize Performance**: Continuous improvement through feedback loops
- **Handle Exceptions**: Intelligent error handling and recovery

### **Learning and Adaptation**
The prompts facilitate:
- **Pattern Recognition**: Historical data analysis for optimization
- **Feedback Integration**: Performance metrics and business impact learning
- **Continuous Improvement**: Adaptive strategies based on operational experience
- **Knowledge Sharing**: Cross-agent coordination and intelligence sharing

### **Business Intelligence Integration**
- **SLA Awareness**: Performance target integration in decision making
- **Cost Optimization**: Resource utilization and cost-benefit analysis
- **Risk Management**: Proactive risk identification and mitigation
- **Compliance Adherence**: Regulatory requirement integration

---

## Prompt Engineering Best Practices

### **Structured Decision Frameworks**
Each prompt provides:
- **Clear Analysis Templates**: Structured input assessment
- **Decision Matrices**: Quantitative decision support
- **Action Guidelines**: Specific operational instructions
- **Success Metrics**: Performance measurement criteria

### **Context Awareness**
Prompts incorporate:
- **Business Context**: Revenue impact, SLA requirements, compliance needs
- **Technical Context**: Resource constraints, system capabilities, integration points
- **Operational Context**: Current system state, historical patterns, performance trends

### **Adaptive Learning**
Built-in mechanisms for:
- **Performance Monitoring**: Success rate tracking and analysis
- **Strategy Refinement**: Continuous optimization based on outcomes
- **Knowledge Accumulation**: Historical pattern recognition and application
- **Cross-Agent Learning**: Shared intelligence and coordination

---

## Integration with AI/ML Models

### **Model-Driven Decisions**
Prompts work in conjunction with ML models to:
- **Enhance Predictions**: Model outputs inform prompt-based decisions
- **Validate Strategies**: ML confidence scores guide strategy selection
- **Optimize Parameters**: Model recommendations fine-tune operational parameters
- **Learn from Outcomes**: Model retraining based on prompt-driven results

### **Feedback Loops**
- **Performance Data**: Prompt decisions feed back to model training
- **Strategy Effectiveness**: Successful strategies inform model optimization
- **Exception Handling**: Edge cases improve model robustness
- **Business Impact**: Real-world outcomes validate model predictions

---

## Operational Excellence

### **24/7 Autonomous Operation**
These prompts enable:
- **Continuous Operation**: Round-the-clock intelligent decision making
- **Exception Handling**: Autonomous problem resolution
- **Performance Optimization**: Real-time strategy adjustment
- **Quality Maintenance**: Consistent high-quality data processing

### **Enterprise Scalability**
- **Horizontal Scaling**: Prompts support multi-instance deployment
- **Load Balancing**: Intelligent workload distribution
- **Resource Optimization**: Dynamic resource allocation based on demand
- **Cost Efficiency**: Optimal resource utilization strategies

### **Compliance and Governance**
- **Audit Trails**: Comprehensive decision logging
- **Regulatory Compliance**: Built-in compliance awareness
- **Data Governance**: Policy enforcement and adherence
- **Risk Management**: Proactive risk identification and mitigation

---

*These AI agent prompts represent the culmination of operational expertise, best practices, and intelligent automation, enabling autonomous, efficient, and reliable financial data ingestion at enterprise scale.*