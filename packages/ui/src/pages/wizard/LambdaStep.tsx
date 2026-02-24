import { Button, Input, Label, Card, CardContent, CardDescription, CardHeader, CardTitle, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui';
import type { WizardStepProps } from '@/types';

export default function LambdaStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const { lambda } = config;

  const updateField = (field: keyof typeof lambda, value: string | number) => {
    onChange({
      lambda: {
        ...lambda,
        [field]: value,
      },
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">Lambda Configuration</h2>
        <p className="text-muted-foreground">Configure AWS Lambda function runtime and resource settings</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Runtime Settings</CardTitle>
          <CardDescription>
            Choose the Node.js runtime version for your Lambda functions
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Label htmlFor="runtime">Runtime</Label>
          <Select
            value={lambda.runtime}
            onValueChange={(value) => updateField('runtime', value)}
          >
            <SelectTrigger id="runtime">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="nodejs18.x">Node.js 18.x</SelectItem>
              <SelectItem value="nodejs20.x">Node.js 20.x</SelectItem>
            </SelectContent>
          </Select>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Resource Settings</CardTitle>
          <CardDescription>
            Configure timeout and memory allocation for Lambda functions
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="timeout">Timeout (seconds)</Label>
            <Input
              id="timeout"
              type="number"
              min="1"
              max="900"
              value={lambda.timeout}
              onChange={(e) => updateField('timeout', parseInt(e.target.value))}
            />
            <p className="text-sm text-muted-foreground mt-1">
              Maximum execution time: 1-900 seconds. Default: 30 seconds
            </p>
          </div>

          <div>
            <Label htmlFor="memory">Memory Size (MB)</Label>
            <Input
              id="memory"
              type="number"
              min="128"
              max="10240"
              step="64"
              value={lambda.memorySize}
              onChange={(e) => updateField('memorySize', parseInt(e.target.value))}
            />
            <p className="text-sm text-muted-foreground mt-1">
              Memory allocation: 128-10240 MB (in 64 MB increments). Default: 256 MB
            </p>
          </div>
        </CardContent>
      </Card>

      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <p className="text-sm text-blue-900">
          <strong>Tip:</strong> Higher memory allocations also increase CPU power. For AI workloads, 
          512 MB or higher is recommended.
        </p>
      </div>

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
