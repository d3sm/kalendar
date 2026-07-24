import { requireNativeView } from 'expo';
import * as React from 'react';

import type { KalendarViewProps } from './Kalendar.types';
import { normalizeProps } from './normalize';

export interface KalendarViewHandle {
  goToToday: () => Promise<void>;
  /** Scroll to `date`'s month and select it. ISO `yyyy-MM-dd`. */
  scrollToDate: (date: string) => Promise<void>;
}

const NativeView: React.ComponentType<
  KalendarViewProps & { testID?: string; ref?: React.Ref<KalendarViewHandle> }
> = requireNativeView('Kalendar');

const KalendarView = React.forwardRef<KalendarViewHandle, KalendarViewProps & { testID?: string }>(
  function KalendarView({ testID, ...props }, ref) {
    const nativeRef = React.useRef<KalendarViewHandle>(null);
    React.useImperativeHandle(
      ref,
      () => ({
        goToToday: () => nativeRef.current!.goToToday(),
        scrollToDate: (date) => nativeRef.current!.scrollToDate(date),
      }),
      [],
    );
    return <NativeView {...normalizeProps(props)} testID={testID} ref={nativeRef} />;
  },
);

export default KalendarView;
