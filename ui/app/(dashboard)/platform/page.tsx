'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { 
  Shield, 
  Rocket, 
  Wind, 
  Brain, 
  BarChart3, 
  Activity,
  Vault,
  User,
  LogOut,
  ExternalLink,
  Loader2
} from 'lucide-react';

const services = [
  {
    name: "ArgoCD",
    description: "GitOps Continuous Deployment", 
    icon: Rocket,
    url: "/argocd",
    namespace: "argocd",
    color: "text-blue-500"
  },
  {
    name: "Vault",
    description: "Secrets Management & Authentication",
    icon: Vault,
    url: "/vault", 
    namespace: "vault",
    color: "text-yellow-500"
  },
  {
    name: "Airflow",
    description: "Workflow Orchestration",
    icon: Wind,
    url: "/airflow",
    namespace: "airflow",
    color: "text-cyan-500"
  },
  {
    name: "MLflow", 
    description: "ML Lifecycle Management",
    icon: Brain,
    url: "/mlflow",
    namespace: "mlflow",
    color: "text-green-500"
  },
  {
    name: "Grafana",
    description: "Monitoring & Observability", 
    icon: BarChart3,
    url: "/grafana",
    namespace: "monitoring",
    color: "text-orange-500"
  },
  {
    name: "Prometheus",
    description: "Metrics Collection",
    icon: Activity,
    url: "/prometheus", 
    namespace: "monitoring",
    color: "text-red-500"
  }
];

function VaultLogin({ onLogin }: { onLogin: (userInfo: any) => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await fetch('/vault/v1/auth/userpass/login/' + username, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password }),
        redirect: 'manual'
      });

      if (response.ok) {
        const data = await response.json();
        localStorage.setItem('vault_token', data.auth.client_token);
        localStorage.setItem('user_info', JSON.stringify({
          username,
          policies: data.auth.policies,
          role: data.auth.metadata?.role || 'user'
        }));
        onLogin({
          username,
          token: data.auth.client_token,
          policies: data.auth.policies,
          role: data.auth.metadata?.role || 'user'
        });
      } else if (response.status === 307 || response.type === 'opaqueredirect') {
        setError('Authentication redirected unexpectedly. Please try again.');
      } else {
        setError('Invalid credentials. Try: admin, developer, or data-scientist');
      }
    } catch (err) {
      setError('Authentication failed. Please check your connection.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[100dvh] flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="flex justify-center">
          <Shield className="h-12 w-12 text-orange-500" />
        </div>
        <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
          BASE Platform
        </h2>
        <p className="mt-2 text-center text-sm text-gray-600">
          Secure Vault Authentication Required
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <Card>
          <CardContent className="p-6">
            <form onSubmit={handleLogin} className="space-y-6">
              <div>
                <Label htmlFor="vault-username" className="block text-sm font-medium text-gray-700">
                  <User className="inline w-4 h-4 mr-2" />
                  Username
                </Label>
                <Input
                  id="vault-username"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="admin, developer, or data-scientist"
                  required
                  className="mt-1"
                />
              </div>
              
              <div>
                <Label htmlFor="vault-password" className="block text-sm font-medium text-gray-700">
                  <Shield className="inline w-4 h-4 mr-2" />
                  Password
                </Label>
                <Input
                  id="vault-password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter your Vault password"
                  required
                  className="mt-1"
                />
              </div>

              {error && (
                <div className="text-red-600 text-sm bg-red-50 p-3 rounded-md">
                  {error}
                </div>
              )}

              <Button
                type="submit"
                className="w-full"
                disabled={loading}
              >
                {loading ? (
                  <>
                    <Loader2 className="animate-spin mr-2 h-4 w-4" />
                    Authenticating...
                  </>
                ) : (
                  <>
                    <Shield className="mr-2 h-4 w-4" />
                    Sign In with Vault
                  </>
                )}
              </Button>
            </form>
            
            <div className="mt-6 text-center">
              <small className="text-gray-500">
                Powered by HashiCorp Vault Authentication
              </small>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function ServiceCard({ service, userInfo }: { service: any; userInfo: any }) {
  const [status] = useState<'healthy' | 'unhealthy' | 'unknown'>('healthy');
  const Icon = service.icon;

  return (
    <Card className="hover:shadow-lg transition-all duration-300 hover:-translate-y-1">
      <CardHeader className="text-center">
        <Icon className={`h-12 w-12 mx-auto ${service.color}`} />
        <CardTitle className="flex items-center justify-center gap-2">
          {service.name}
          <div className={`w-2 h-2 rounded-full ${
            status === 'healthy' ? 'bg-green-500' : 
            status === 'unhealthy' ? 'bg-red-500' : 'bg-yellow-500'
          }`} />
        </CardTitle>
        <CardDescription>{service.description}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="text-center space-y-4">
          <Badge variant="secondary">
            Namespace: {service.namespace}
          </Badge>
          <Button
            asChild
            variant="outline"
            className="w-full"
          >
            <a href={service.url} target="_blank" rel="noopener noreferrer">
              <ExternalLink className="mr-2 h-4 w-4" />
              Open Service
            </a>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}

export default function PlatformDashboard() {
  const [userInfo, setUserInfo] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('vault_token');
    const savedUserInfo = localStorage.getItem('user_info');

    if (token && savedUserInfo) {
      fetch('/vault/v1/auth/token/lookup-self', {
        headers: { 'X-Vault-Token': token },
        redirect: 'manual'
      })
      .then(response => {
        if (response.ok) {
          setUserInfo(JSON.parse(savedUserInfo));
        } else {
          localStorage.removeItem('vault_token');
          localStorage.removeItem('user_info');
        }
      })
      .catch(() => {
        localStorage.removeItem('vault_token');
        localStorage.removeItem('user_info');
      })
      .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  const handleLogin = (userData: any) => {
    setUserInfo(userData);
  };

  const handleLogout = () => {
    localStorage.removeItem('vault_token');
    localStorage.removeItem('user_info');
    setUserInfo(null);
  };

  if (loading) {
    return (
      <div className="min-h-[100dvh] flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="h-8 w-8 animate-spin mx-auto text-orange-500" />
          <h4 className="mt-4 text-lg font-medium">Checking authentication...</h4>
          <p className="text-gray-500">Verifying Vault token</p>
        </div>
      </div>
    );
  }

  if (!userInfo) {
    return <VaultLogin onLogin={handleLogin} />;
  }

  return (
    <div className="min-h-[100dvh] bg-gray-50">
      {/* Navigation */}
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <Shield className="h-8 w-8 text-orange-500 mr-3" />
              <h1 className="text-xl font-semibold text-gray-900">BASE Platform</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-700">
                <User className="inline w-4 h-4 mr-1" />
                Welcome, {userInfo.username}
              </span>
              <Button variant="outline" size="sm" onClick={handleLogout}>
                <LogOut className="mr-2 h-4 w-4" />
                Logout
              </Button>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-12 px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Enterprise Data Platform Services
          </h1>
          <p className="text-xl text-gray-600 mb-6">
            Authenticated access to your platform services
          </p>
          <div className="flex justify-center space-x-2">
            <Badge className="bg-green-100 text-green-800 border-green-200">
              <Shield className="w-3 h-3 mr-1" />
              Authenticated
            </Badge>
            <Badge className="bg-blue-100 text-blue-800 border-blue-200">
              Platform Cluster
            </Badge>
            <Badge className="bg-orange-100 text-orange-800 border-orange-200">
              AWS us-east-1
            </Badge>
          </div>
        </div>

        {/* Services Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12">
          {services.map((service, index) => (
            <ServiceCard key={index} service={service} userInfo={userInfo} />
          ))}
        </div>

        {/* Session Information */}
        <Card>
          <CardHeader>
            <CardTitle>
              <User className="inline mr-2 h-5 w-5" />
              Session Information
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div>
                <strong>User:</strong> {userInfo.username}
              </div>
              <div>
                <strong>Role:</strong> {userInfo.role}
              </div>
              <div>
                <strong>Policies:</strong> {userInfo.policies?.join(', ')}
              </div>
              <div>
                <strong>Environment:</strong> Development
              </div>
            </div>
          </CardContent>
        </Card>
      </main>
    </div>
  );
}