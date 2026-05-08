import type { Config } from 'tailwindcss'
const config: Config = {
  content: ['./pages/**/*.{ts,tsx}','./components/**/*.{ts,tsx}','./app/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        display:['var(--font-syne)','sans-serif'],
        body:['var(--font-dm-sans)','sans-serif'],
        mono:['var(--font-jetbrains)','monospace'],
      },
      colors: {
        purple:'#7C6FFF', teal:'#00E5C0', gold:'#FFD100',
        'brand-dark':'#07070F','brand-card':'#0E0E1A','brand-card2':'#12121E',
        'brand-border':'#1E1E35','brand-muted':'#5A5A7A',
      },
    },
  },
  plugins:[],
}
export default config
