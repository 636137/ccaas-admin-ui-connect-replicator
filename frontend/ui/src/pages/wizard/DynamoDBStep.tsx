import { Button, Label, Card, CardContent, CardDescription, CardHeader, CardTitle, Select, SelectContent, SelectItem, SelectTrigger, SelectValue, Switch } from '@/components/ui';
import type { WizardStepProps } from '@/types';

export default function DynamoDBStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const { dynamodb } = config;

  const updateField = (field: keyof typeof dynamodb, value: string | boolean) => {
    onChange({
      dynamodb: {
        ...dynamodb,
        [field]: value,
      },
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">DynamoDB Configuration</h2>
        <p className="text-muted-foreground">Configure database billing and data protection settings</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Billing Mode</CardTitle>
          <CardDescription>
            Choose how you'll be charged for read and write throughput
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Label htmlFor="billing">Billing Mode</Label>
          <Select
            value={dynamodb.billingMode}
            onValueChange={(value) => updateField('billingMode', value)}
          >
            <SelectTrigger id="billing">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="PAY_PER_REQUEST">
                Pay Per Request (On-Demand)
              </SelectItem>
              <SelectItem value="PROVISIONED">
                Provisioned (Reserved Capacity)
              </SelectItem>
            </SelectContent>
          </Select>
          <p className="text-sm text-muted-foreground mt-2">
            {dynamodb.billingMode === 'PAY_PER_REQUEST' 
              ? 'Pay only for what you use. Best for unpredictable workloads.'
              : 'Reserve capacity for consistent performance. Best for predictable workloads.'}
          </p>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Data Protection</CardTitle>
          <CardDescription>
            Enable encryption and backup features for your data
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="encryption">Enable Encryption at Rest</Label>
              <p className="text-sm text-muted-foreground">
                Use AWS-managed keys to encrypt data stored in DynamoDB
              </p>
            </div>
            <Switch
              id="encryption"
              checked={dynamodb.enableEncryption}
              onCheckedChange={(checked) => updateField('enableEncryption', checked)}
            />
          </div>

          <div className="flex items-center justify-between">
            <div className="space-y-0.5">
              <Label htmlFor="pitr">Enable Point-in-Time Recovery</Label>
              <p className="text-sm text-muted-foreground">
                Continuous backups for the last 35 days
              </p>
            </div>
            <Switch
              id="pitr"
              checked={dynamodb.enablePointInTimeRecovery}
              onCheckedChange={(checked) => updateField('enablePointInTimeRecovery', checked)}
            />
          </div>
        </CardContent>
      </Card>

      {config.security.enableFedRampCompliance && (
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
          <p className="text-sm text-amber-900">
            <strong>FedRAMP Compliance:</strong> Encryption and Point-in-Time Recovery are required 
            for FedRAMP compliance and cannot be disabled.
          </p>
        </div>
      )}

      <div className="flex justify-between">
        <Button variant="outline" onClick={onPrevious}>
          Previous
        </Button>
        <Button onClick={onNext}>
          Next
        </Button>
      </div>
    </div>
  );
}
