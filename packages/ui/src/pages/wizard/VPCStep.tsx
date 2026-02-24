import { useState } from 'react';
import type { WizardStepProps } from '../../types';
import { Button, Input, Label, Switch } from '../../components/ui';
import { validateSection } from '../../services/validation';
import { AlertCircle } from 'lucide-react';

export default function VPCStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const [errors, setErrors] = useState<Record<string, string>>({});

  const handleUseExistingChange = (checked: boolean) => {
    onChange({
      vpc: {
        ...config.vpc,
        useExistingVpc: checked,
      },
    });
  };

  const handleVpcCidrChange = (value: string) => {
    onChange({
      vpc: {
        ...config.vpc,
        vpcCidr: value,
      },
    });
  };

  const handleVpcIdChange = (value: string) => {
    onChange({
      vpc: {
        ...config.vpc,
        vpcId: value,
      },
    });
  };

  const handleNatGatewayChange = (checked: boolean) => {
    onChange({
      vpc: {
        ...config.vpc,
        enableNatGateway: checked,
      },
    });
  };

  const handleSingleNatChange = (checked: boolean) => {
    onChange({
      vpc: {
        ...config.vpc,
        singleNatGateway: checked,
      },
    });
  };

  const handleVpcEndpointsChange = (checked: boolean) => {
    onChange({
      vpc: {
        ...config.vpc,
        enableVpcEndpoints: checked,
      },
    });
  };

  const handleNext = () => {
    const validation = validateSection('vpc', config.vpc);
    
    if (!validation.valid) {
      const errorMap: Record<string, string> = {};
      validation.errors.forEach((err) => {
        errorMap[err.field] = err.message;
      });
      setErrors(errorMap);
      return;
    }
    
    setErrors({});
    onNext();
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold mb-2">VPC Configuration</h2>
        <p className="text-muted-foreground">
          Configure Virtual Private Cloud networking for enhanced security.
        </p>
      </div>

      <div className="space-y-4">
        <div className="flex items-center justify-between border rounded-lg p-4">
          <div className="space-y-0.5">
            <Label htmlFor="useExisting">Use Existing VPC</Label>
            <p className="text-sm text-muted-foreground">
              Connect to an existing VPC instead of creating a new one
            </p>
          </div>
          <Switch
            id="useExisting"
            checked={config.vpc.useExistingVpc}
            onCheckedChange={handleUseExistingChange}
          />
        </div>

        {!config.vpc.useExistingVpc ? (
          <>
            <div>
              <Label htmlFor="vpcCidr">VPC CIDR Block</Label>
              <Input
                id="vpcCidr"
                placeholder="10.0.0.0/16"
                value={config.vpc.vpcCidr || ''}
                onChange={(e) => handleVpcCidrChange(e.target.value)}
                className={errors['vpc.vpcCidr'] ? 'border-red-500' : ''}
              />
              {errors['vpc.vpcCidr'] && (
                <p className="text-sm text-red-500 mt-1">{errors['vpc.vpcCidr']}</p>
              )}
              <p className="text-sm text-muted-foreground mt-1">
                IP address range for the VPC (e.g., 10.0.0.0/16)
              </p>
            </div>

            <div className="space-y-4 border rounded-lg p-4">
              <div className="flex items-center justify-between">
                <div className="space-y-0.5">
                  <Label htmlFor="natGateway">NAT Gateway</Label>
                  <p className="text-sm text-muted-foreground">
                    Enable internet access for private subnets
                  </p>
                </div>
                <Switch
                  id="natGateway"
                  checked={config.vpc.enableNatGateway}
                  onCheckedChange={handleNatGatewayChange}
                />
              </div>

              {config.vpc.enableNatGateway && (
                <div className="flex items-center justify-between pl-4">
                  <div className="space-y-0.5">
                    <Label htmlFor="singleNat">Single NAT Gateway</Label>
                    <p className="text-sm text-muted-foreground">
                      Use one NAT Gateway (cost savings, reduced availability)
                    </p>
                  </div>
                  <Switch
                    id="singleNat"
                    checked={config.vpc.singleNatGateway}
                    onCheckedChange={handleSingleNatChange}
                  />
                </div>
              )}
            </div>
          </>
        ) : (
          <>
            <div>
              <Label htmlFor="vpcId">VPC ID</Label>
              <Input
                id="vpcId"
                placeholder="vpc-xxxxxxxxxxxxxxxxx"
                value={config.vpc.vpcId || ''}
                onChange={(e) => handleVpcIdChange(e.target.value)}
              />
              <p className="text-sm text-muted-foreground mt-1">
                ID of the existing VPC to use
              </p>
            </div>

            <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-4 flex gap-2">
              <AlertCircle className="h-5 w-5 text-yellow-600 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-yellow-900">
                <strong>Note:</strong> When using an existing VPC, you'll need to manually
                configure subnet IDs and security group IDs in the generated terraform.tfvars file.
              </div>
            </div>
          </>
        )}

        <div className="flex items-center justify-between border rounded-lg p-4">
          <div className="space-y-0.5">
            <Label htmlFor="vpcEndpoints">VPC Endpoints</Label>
            <p className="text-sm text-muted-foreground">
              Private connections to AWS services (recommended for security)
            </p>
          </div>
          <Switch
            id="vpcEndpoints"
            checked={config.vpc.enableVpcEndpoints}
            onCheckedChange={handleVpcEndpointsChange}
          />
        </div>

        {config.security.enableFedRampCompliance && (
          <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
            <p className="text-sm text-blue-900">
              <strong>FedRAMP Requirement:</strong> VPC deployment with endpoints is required
              for FedRAMP compliance.
            </p>
          </div>
        )}
      </div>

      <div className="flex justify-between pt-6">
        <Button variant="outline" onClick={onPrevious}>
          Previous
        </Button>
        <Button onClick={handleNext}>Next</Button>
      </div>
    </div>
  );
}
