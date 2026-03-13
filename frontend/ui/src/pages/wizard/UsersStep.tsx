import { Button, Input, Label, Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui';
import { Plus, Trash2 } from 'lucide-react';
import type { WizardStepProps } from '@/types';

export default function UsersStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const { users } = config;

  const addAgentEmail = () => {
    onChange({
      users: {
        ...users,
        agentEmails: [...users.agentEmails, ''],
      },
    });
  };

  const updateAgentEmail = (index: number, value: string) => {
    const newEmails = [...users.agentEmails];
    newEmails[index] = value;
    onChange({
      users: {
        ...users,
        agentEmails: newEmails,
      },
    });
  };

  const removeAgentEmail = (index: number) => {
    if (users.agentEmails.length > 1) {
      onChange({
        users: {
          ...users,
          agentEmails: users.agentEmails.filter((_, i) => i !== index),
        },
      });
    }
  };

  const updateSupervisorEmail = (value: string) => {
    onChange({
      users: {
        ...users,
        supervisorEmail: value,
      },
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">User Configuration</h2>
        <p className="text-muted-foreground">Configure agent and supervisor accounts for your contact center</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Agent Emails</CardTitle>
          <CardDescription>
            Add email addresses for agents who will handle customer interactions. At least one agent is required.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {users.agentEmails.map((email, index) => (
            <div key={index} className="flex items-center gap-2">
              <div className="flex-1">
                <Label htmlFor={`agent-${index}`}>Agent {index + 1}</Label>
                <Input
                  id={`agent-${index}`}
                  type="email"
                  placeholder="agent@example.com"
                  value={email}
                  onChange={(e) => updateAgentEmail(index, e.target.value)}
                />
              </div>
              {users.agentEmails.length > 1 && (
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => removeAgentEmail(index)}
                  className="mt-6"
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              )}
            </div>
          ))}
          
          {users.agentEmails.length < 10 && (
            <Button
              variant="outline"
              onClick={addAgentEmail}
              className="w-full"
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Agent
            </Button>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Supervisor Email</CardTitle>
          <CardDescription>
            Email address for the supervisor who will manage agents and monitor performance
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Label htmlFor="supervisor">Supervisor Email</Label>
          <Input
            id="supervisor"
            type="email"
            placeholder="supervisor@example.com"
            value={users.supervisorEmail}
            onChange={(e) => updateSupervisorEmail(e.target.value)}
          />
        </CardContent>
      </Card>

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
