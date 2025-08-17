'use client';

import { DeploymentOptions } from '../deployment-options';

export default function DeploymentWizardPage() {
  const handleOptionSelect = (option: any) => {
    console.log('Selected option:', option);
    // TODO: Navigate to deployment configuration
  };

  return (
    <main className="flex-1">
      <div className="py-16">
        <DeploymentOptions onOptionSelect={handleOptionSelect} />
      </div>
    </main>
  );
}