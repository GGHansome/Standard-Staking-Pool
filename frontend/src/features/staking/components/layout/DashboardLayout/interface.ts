import type { ReactNode } from 'react'

export type DashboardLayoutProps = {
  isPaused: boolean
  configWarnings: string[]
  children: ReactNode
}