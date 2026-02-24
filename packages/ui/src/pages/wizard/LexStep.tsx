import { Button, Input, Label, Card, CardContent, CardDescription, CardHeader, CardTitle, Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui';
import type { WizardStepProps } from '@/types';

const POLLY_VOICES = [
  { id: 'Ruth', name: 'Ruth (US English, Female)', language: 'en-US' },
  { id: 'Matthew', name: 'Matthew (US English, Male)', language: 'en-US' },
  { id: 'Joanna', name: 'Joanna (US English, Female)', language: 'en-US' },
  { id: 'Joey', name: 'Joey (US English, Male)', language: 'en-US' },
  { id: 'Salli', name: 'Salli (US English, Female)', language: 'en-US' },
];

const LOCALES = [
  { id: 'en_US', name: 'English (US)' },
  { id: 'en_GB', name: 'English (UK)' },
  { id: 'es_US', name: 'Spanish (US)' },
  { id: 'fr_CA', name: 'French (Canada)' },
];

export default function LexStep({ config, onChange, onNext, onPrevious }: WizardStepProps) {
  const { lex } = config;

  const updateField = (field: keyof typeof lex, value: string | number) => {
    onChange({
      lex: {
        ...lex,
        [field]: value,
      },
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">Lex Bot Configuration</h2>
        <p className="text-muted-foreground">Configure voice and natural language understanding settings</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Voice Settings</CardTitle>
          <CardDescription>
            Choose the Amazon Polly voice for your bot's text-to-speech responses
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="voice">Voice</Label>
            <Select
              value={lex.voiceId}
              onValueChange={(value) => updateField('voiceId', value)}
            >
              <SelectTrigger id="voice">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {POLLY_VOICES.map((voice) => (
                  <SelectItem key={voice.id} value={voice.id}>
                    {voice.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div>
            <Label htmlFor="locale">Locale</Label>
            <Select
              value={lex.locale}
              onValueChange={(value) => updateField('locale', value)}
            >
              <SelectTrigger id="locale">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {LOCALES.map((locale) => (
                  <SelectItem key={locale.id} value={locale.id}>
                    {locale.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>NLU Confidence Threshold</CardTitle>
          <CardDescription>
            Set the minimum confidence score (0-1) for intent matching. Lower values are more permissive.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <Label htmlFor="threshold">Confidence Threshold</Label>
            <Input
              id="threshold"
              type="number"
              min="0"
              max="1"
              step="0.05"
              value={lex.nluConfidenceThreshold}
              onChange={(e) => updateField('nluConfidenceThreshold', parseFloat(e.target.value))}
            />
            <p className="text-sm text-muted-foreground mt-1">
              Current: {lex.nluConfidenceThreshold} (Recommended: 0.40)
            </p>
          </div>
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
