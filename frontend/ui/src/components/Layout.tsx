import { ReactNode } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { 
  LayoutDashboard, 
  Wand2, 
  Cpu, 
  Rocket,
  Settings,
  Shield,
  GitMerge
} from 'lucide-react'

interface LayoutProps {
  children: ReactNode
}

const navigation = [
  { name: 'Dashboard', href: '/', icon: LayoutDashboard },
  { name: 'Configuration Wizard', href: '/wizard', icon: Wand2 },
  { name: 'AI Models', href: '/models', icon: Cpu },
  { name: 'Deployments', href: '/deployments', icon: Rocket },
  { name: 'Connect Replicator', href: '/connect', icon: GitMerge },
]

export function Layout({ children }: LayoutProps) {
  const location = useLocation()

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Sidebar */}
      <div className="fixed inset-y-0 left-0 w-64 bg-slate-900">
        {/* Logo */}
        <div className="flex h-16 items-center gap-2 px-6 border-b border-slate-700">
          <Shield className="h-8 w-8 text-blue-400" />
          <div>
            <h1 className="text-white font-semibold">Gov CCaaS</h1>
            <p className="text-xs text-slate-400">Admin Portal</p>
          </div>
        </div>

        {/* Navigation */}
        <nav className="mt-6 px-3">
          <ul className="space-y-1">
            {navigation.map((item) => {
              const isActive = location.pathname === item.href || 
                (item.href !== '/' && location.pathname.startsWith(item.href))
              return (
                <li key={item.name}>
                  <Link
                    to={item.href}
                    className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
                      isActive
                        ? 'bg-blue-600 text-white'
                        : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                    }`}
                  >
                    <item.icon className="h-5 w-5" />
                    {item.name}
                  </Link>
                </li>
              )
            })}
          </ul>
        </nav>

        {/* Version info */}
        <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-700">
          <div className="flex items-center gap-2 text-xs text-slate-400">
            <Settings className="h-4 w-4" />
            <span>Version 1.0.0</span>
          </div>
        </div>
      </div>

      {/* Main content */}
      <div className="pl-64">
        <main className="p-8">
          {children}
        </main>
      </div>
    </div>
  )
}
