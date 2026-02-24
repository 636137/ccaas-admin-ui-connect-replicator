import { useState } from 'react';
import type { WizardStepProps } from '../../types';
import { Button, Input, Label, Switch } from '../../components/ui';
import { validateSection } from '../../services/validation';

export default function BackupStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const [errors, setErrors] = useState<Record<string, string>>({});

  const handleEnableBackupChange = (checked: boolean) => {
    onChange({
      backup: {
        ...config.backup,
        enableBackup: checked,
      },
    });
  };

  const handleCrossRegionChange = (checked: boolean) => {
    onChange({
      backup: {
        ...config.backup,
        enableCrossRegionBackup: checked,
      },
    });
  };

  const handleDrVaultChange = (value: string) => {
    onChange({
      backup: {
        ...config.backup,
        drVaultArn: value || undefined,
      },
    });
  };

  const handleValidationChange = (checked: boolean) => {
    onChange({
      validation: {
        ...config.validation,
        enableValidationModule: checked,
      },
    });
  };

  const handleNotificationEmailChange = (value: string) => {
    onChange({
      validation: {
        ...config.validation,
        validationNotificationEmail: value || undefined,
      },
    });
  };

  const handleAccuracyThresholdChange = (value: string) => {
    const numValue = parseFloat(value);
    if (!isNaN(numValue)) {
      onChange({
        validation: {
          ...config.validation,
          aiAccuracyThreshold: numValue,
        },
      });
    }
  };

  const handleLatencyThresholdChange = (value: string) => {
    const numValue = parseInt(value, 10);
    if (!isNaN(numValue)) {
      onChange({
        validation: {
          ...config.validation,
          aiLatencyThreshold: numValue,
        },
      });
    }
  };

  const handleNext = () => {
    const backupValidation = validateSection('backup', config.backup);
    const validationValidation = validateSection('validation', config.validation);
    
    if (!backupValidation.valid || !validationValidation.valid) {
      const errorMap: Record<string, string> = {};
      [...backupValidation.errors, ...validationValidation.errors].forEach((err) => {
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
        <h2 className="text-2xl font-bold mb-2">Backup & Validation</h2>
        <p className="text-muted-foreground">
          Configure backup strategies and AI validation monitoring.
        </p>
      </div>

      <div className="space-y-6">
        {/* Backup Section */}
        <div className="space-y-4">
          <h3 className="text-lg font-semibold">Backup Configuration</h3>
          
          <div className="flex items-center justify-between border rounded-lg p-4">
            <div className="space-y-0.5">
              <Label htmlFor="enableBackup">Enable AWS Backup</Label>
              <p className="text-sm text-muted-foreground">
                Automated backups for DynamoDB and other resources
              </p>
            </div>
            <Switch
              id="enableBackup"
              checked={config.backup.enableBackup}
              onCheckedChange={handleEnableBackupChange}
            />
          </div>

          {config.backup.enableBackup && (
            <>
              <div className="flex items-center justify-between border rounded-lg p-4">
                <div className="space-y-0.5">
                  <Label htmlFor="crossRegion">Cross-Region Backup</Label>
                  <p className="text-sm text-muted-foreground">
                    Replicate backups to another region for disaster recovery
                  </p>
                </div>
                <Switch
                  id="crossRegion"
                  checked={config.backup.enableCrossRegionBackup}
                  onCheckedChange={handleCrossRegionChange}
                />
              </div>

              {config.backup.enableCrossRegionBackup && (
                <div>
                  <Label htmlFor="drVault">DR Vault ARN (Optional)</Label>
                  <Input
                    id="drVault"
                    placeholder="arn:aws:backup:us-west-2:123456789012:backup-vault:my-vault"
                    value={config.backup.drVaultArn || ''}
                    onChange={(e) => handleDrVaultChange(e.target.value)}
                  />
                  <p className="text-sm text-muted-foreground mt-1">
                    Existing backup vault in DR region (leave empty to create new)
                  </p>
                </div>
              )}
            </>
          )}
        </div>

        {/* Validation Module Section */}
        <div className="space-y-4 border-t pt-6">
          <h3 className="text-lg font-semibold">AI Validation Module</h3>
          
          <div className="flex items-center justify-between border rounded-lg p-4">
            <div className="space-y-0.5">
              <Label htmlFor="validationModule">Enable Validation Module</Label>
              <p className="text-sm text-muted-foreground">
                Monitor AI agent accuracy and performance
              </p>
            </div>
            <Switch
              id="validationModule"
              checked={config.validation.enableValidationModule}
              onCheckedChange={handleValidationChange}
            />
          </div>

          {config.validation.enableValidationModule && (
            <>
              <div>
                <Label htmlFor="validationEmail">Notification Email</Label>
                <Input
                  id="validationEmail"
                  type="email"
                  placeholder="validation@example.com"
                  value={config.validation.validationNotificationEmail || ''}
                  onChange={(e) => handleNotificationEmailChange(e.target.value)}
                />
                <p className="text-sm text-muted-foreground mt-1">
                  Email address for validation alerts
                </p>
              </div>

              <div>
                <Label htmlFor="accuracyThreshold">AI Accuracy Threshold</Label>
                <Input
                  id="accuracyThreshold"
                  type="number"
                  min="0"
                  max="1"
                  step="0.05"
                  value={config.validation.aiAccuracyThreshold}
                  onChange={(e) => handleAccuracyThresholdChange(e.target.value)}
                  className={errors['validation.aiAccuracyThreshold'] ? 'border-red-500' : ''}
                />
                {errors['validation.aiAccuracyThreshold'] && (
                  <p className="text-sm text-red-500 mt-1">
                    {errors['validation.aiAccuracyThreshold']}
                  </p>
                )}
                <p className="text-sm text-muted-foreground mt-1">
                  Minimum acceptable accuracy (0-1, default: 0.85)
                </p>
              </div>

              <div>
                <Label htmlFor="latencyThreshold">AI Latency Threshold (ms)</Label>
                <Input
                  id="latencyThreshold"
                  type="number"
                  min="0"
                  value={config.validation.aiLatencyThreshold}
                  onChange={(e) => handleLatencyThresholdChange(e.target.value)}
                  className={errors['validation.aiLatencyThreshold'] ? 'border-red-500' : ''}
                />
                {errors['validation.aiLatencyThreshold'] && (
                  <p className="text-sm text-red-500 mt-1">
                    {errors['validation.aiLatencyThreshold']}
                  </p>
                )}
                <p className="text-sm text-muted-foreground mt-1">
                  Maximum acceptable response time in milliseconds
                </p>
              </div>

              <div className="rounded-lg border p-4 bg-muted/50">
                <h4 className="font-medium mb-2">Validation Features</h4>
                <ul className="text-sm text-muted-foreground space-y-1">
                  <li>• Real-time accuracy monitoring</li>
                  <li>• Response latency tracking</li>
                  <li>• Intent recognition validation</li>
                  <li>• Automated alerting on threshold violations</li>
                </ul>
              </div>
            </>
          )}
        </div>
      </div>

      <div className="flex justify-between pt-6">
        <Button variant="outline" onClick={onPrevious}>
          Previous
        </Button>
        <Button onClick={handleNext}>Next: Review</Button>
      </div>
    </div>
  );
}
