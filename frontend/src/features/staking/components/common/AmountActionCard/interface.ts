export type AmountActionCardProps = {
  title: string
  tokenSymbol: string
  primaryLabel: string
  secondaryLabel?: string
  disabled?: boolean
  primaryDisabled?: boolean
  secondaryDisabled?: boolean
  onPrimary: (amount: string) => Promise<void>
  onSecondary?: (amount: string) => Promise<void>
}