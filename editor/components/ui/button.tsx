import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '../../lib/utils';
// N's buttons: the accent for the one thing to do, red for one that deletes, quiet for the rest, and round icons.
const buttonVariants = cva('inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-full text-[15px] font-medium transition-colors disabled:pointer-events-none disabled:opacity-40 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent', {
  variants: {
    variant: { default: 'bg-accent text-accent-ink hover:brightness-110', danger: 'bg-error text-paper hover:brightness-110', quiet: 'text-ink hover:bg-hover', outline: 'border border-line bg-surface text-ink hover:bg-hover' },
    size: { default: 'h-10 px-4', small: 'h-8 px-3 text-sm', icon: 'size-10' },
  },
  defaultVariants: { variant: 'default', size: 'default' },
});
export function Button({ className, variant, size, asChild = false, ...props }: React.ComponentProps<'button'> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : 'button';
  return <Comp data-slot="button" className={cn(buttonVariants({ variant, size }), className)} {...props} />;
}
