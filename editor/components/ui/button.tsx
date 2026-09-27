import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '../../lib/utils';
const buttonVariants = cva('inline-flex items-center justify-center whitespace-nowrap disabled:pointer-events-none disabled:opacity-50', {
  variants: { variant: { default: 'bg-[var(--ink)] text-[var(--paper)]', ghost: 'bg-transparent text-[var(--ink)]' }, size: { default: 'px-4 py-2', icon: 'size-10' } },
  defaultVariants: { variant: 'default', size: 'default' }
});
export function Button({ className, variant, size, asChild = false, ...props }: React.ComponentProps<'button'> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : 'button';
  return <Comp data-slot="button" className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
