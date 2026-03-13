import { useState } from 'react';
import type { WizardStepProps } from '../../types';
import { Button, Input, Label, Switch } from '../../components/ui';
import { validateSection } from '../../services/validation';

export default function MonitoringStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const [errors, setErrors] = useState<Record<string, string>>({});

  const handleSnsTopicChange = (value: string) => {
    onChange({
      monitoring: {
        ...config.monitoring,
        alarmSnsTopicArn: value || undefined,
      },
    });
  };

  const handleDetailedMonitoringChange = (checked: boolean) => {
    onChange({
      monitoring: {
        ...config.monitoring,
        enableDetailedMonitoring: checked,
      },
    });
  };

  const handleLogRetentionChange = (value: string) => {
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      onChange({
        monitoring: {
          ...config.monitoring,
          logRetentionDays: numValue,
        },
      });
    }
  };

  const handleNext = () => {
    const validation = validateSection('monitoring', config.monitoring);
    
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
        <h2 className="text-2xl font-bold mb-2">Monitoring & Logging</h2>
        <p className="text-muted-foreground">
          Configure CloudWatch monitoring and alerting for your deployment.
        </p>
      </div>

      <div className="space-y-4">
        <div>
          <Label htmlFor="snsTopic">Alarm SNS Topic ARN (Optional)</Label>
          <Input
            id="snsTopic"
            placeholder="arn:aws:sns:us-east-1:123456789012:my-topic"
            value={config.monitoring.alarmSnsTopicArn || ''}
            onChange={(e) => handleSnsTopicChange(e.target.value)}
          />
          <p className="text-sm text-muted-foreground mt-1">
            Existing SNS topic to receive CloudWatch alarm notifications
          </p>
        </div>

        <div className="flex items-center justify-between border rounded-lg p-4">
          <div className="space-y-0.5">
            <Label htmlFor="detailedMonitoring">Detailed Monitoring</Label>
            <p className="text-sm text-muted-foreground">
              Enable 1-minute metrics (additional cost)
            </p>
          </div>
          <Switch
            id="detailedMonitoring"
            checked={config.monitoring.enableDetailedMonitoring}
            onCheckedChange={handleDetailedMonitoringChange}
          />
        </div>

        <div>
          <Label htmlFor="logRetention">CloudWatch Log Retention (days)</Label>
          <Input
            id="logRetention"
            type="number"
            min="1"
            value={config.monitoring.logRetentionDays}
            onChange={(e) => handleLogRetentionChange(e.target.value)}
            className={errors['monitoring.logRetentionDays'] ? 'border-red-500' : ''}
          />
          {errors['monitoring.logRetentionDays'] && (
            <p className="text-sm text-red-500 mt-1">{errors['monitoring.logRetentionDays']}</p>
          )}
          <p className="text-sm text-muted-foreground mt-1">
            How long to retain CloudWatch logs (90+ days recommended)
          </p>
        </div>

        <div className="rounded-lg border p-4 bg-muted/50">
          <h4 className="font-medium mb-2">Monitoring Features</h4>
          <ul className="text-sm text-muted-foreground space-y-1">
            <li>• Lambda function errors and throttles</li>
            <li>• DynamoDB table capacity and latency</li>
            <li>• Connect contact flow errors</li>
            <li>• Lex bot intent accuracy</li>
            <li>• VPC flow logs (if enabled)</li>
          </ul>
        </div>

        <div className="rounded-lg border p-4 bg-muted/50">
          <h4 className="font-medium mb-2">Cost Considerations</h4>
          <ul className="text-sm text-muted-foreground space-y-1">
            <li>• Standard monitoring: Free (5-minute metrics)</li>
            <li>• Detailed monitoring: ~$2-5/month per resource</li>
            <li>• Log storage: ~$0.50/GB/month</li>
            <li>• Expected monthly cost: $5-20</li>
          </ul>
        </div>
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
