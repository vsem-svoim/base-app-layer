import { Button } from '@/components/ui/button';
import { ArrowRight, CreditCard, Database } from 'lucide-react';
import { Terminal } from './terminal';

export default function HomePage() {
  return (
    <main>
      <section className="py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-12 lg:gap-8">
            <div className="sm:text-center md:max-w-2xl md:mx-auto lg:col-span-6 lg:text-left">
              <h1 className="text-4xl font-bold text-gray-900 tracking-tight sm:text-5xl md:text-6xl">
                From NOISY streams
                <span className="block text-orange-600"> to clear STRATEGY.</span>
              </h1>
              <p className="mt-3 text-base text-gray-500 sm:mt-5 sm:text-xl lg:text-lg xl:text-xl">
                Modular Data Processing Platform — Built for every domain, engineered to scale without complexity
              </p>
              <div className="mt-8 sm:max-w-lg sm:mx-auto sm:text-center lg:text-left lg:mx-0">
                <a
                  href="#deployment"
                  
                >
                  <Button
                    size="lg"
                    variant="outline"
                    className="text-lg rounded-full"
                  >
                    Start Building Analytics
                    <ArrowRight className="ml-2 h-5 w-5" />
                  </Button>
                </a>
              </div>
            </div>
            <div className="mt-12 relative sm:max-w-lg sm:mx-auto lg:mt-0 lg:max-w-none lg:mx-0 lg:col-span-6 lg:flex lg:items-center">
              <Terminal />
            </div>
          </div>
        </div>
      </section>

      <section className="py-16 bg-white w-full">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-3 lg:gap-8">
            <div>
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <svg viewBox="0 0 24 24" className="h-6 w-6">
                  <path
                    fill="currentColor"
                    d="M12 2L2 7v10c0 5.55 3.84 9.739 9 11 5.16-1.261 9-5.45 9-11V7l-10-5z"
                  />
                </svg>
              </div>
              <div className="mt-5">
                <h2 className="text-lg font-medium text-gray-900">
                  Multi-Environment Deployment — No Limits, No Boundaries
                </h2>
                <p className="mt-2 text-base text-gray-500">
                  From any cloud to your own data center, deploy anywhere with auto-scaling, self-healing, and zero-downtime updates.
                </p>
              </div>
            </div>

            <div className="mt-10 lg:mt-0">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <Database className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h2 className="text-lg font-medium text-gray-900">
                  Micro-Orchestrated Agents
                </h2>
                <p className="mt-2 text-base text-gray-500">
                  Intelligent micro-services that work as specialized agents - data ingestion, 
                  processing, analysis, and reporting agents collaborate automatically to 
                  transform your raw financial data into insights.
                </p>
              </div>
            </div>

            <div className="mt-10 lg:mt-0">
              <div className="flex items-center justify-center h-12 w-12 rounded-md bg-orange-500 text-white">
                <CreditCard className="h-6 w-6" />
              </div>
              <div className="mt-5">
                <h2 className="text-lg font-medium text-gray-900">
                  Open Source & Modular
                </h2>
                <p className="mt-2 text-base text-gray-500">
                  Fully open-source platform with modular components you can customize, 
                  extend, or replace. Add new data sources, create custom analytics, 
                  or integrate with existing systems without vendor lock-in.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="py-16 bg-gray-50" id="deployment">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="lg:grid lg:grid-cols-2 lg:gap-8 lg:items-center">
            <div>
              <h2 className="text-3xl font-bold text-gray-900 sm:text-4xl">
                Everyone Has Data. Few Know How To Use It.
              </h2>
              <p className="mt-3 max-w-3xl text-lg text-gray-500">
                FinPortIQ bridges the gap between raw financial data and actionable insights. 
                Our micro-orchestrated agents automatically process, analyze, and present 
                your data in ways that drive better business decisions.
              </p>
            </div>
            <div className="mt-8 lg:mt-0 flex justify-center lg:justify-end">
              <a href="/deployment-wizard" >
                <Button
                  size="lg"
                  variant="outline"
                  className="text-lg rounded-full"
                >
                  Deploy Your Platform
                  <ArrowRight className="ml-3 h-6 w-6" />
                </Button>
              </a>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}