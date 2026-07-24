import { TrueSheet } from '@lodev09/react-native-true-sheet';
import {
  KalendarEvent,
  KalendarLevel,
  DayPressEvent,
  EventChangeEvent,
  EventDeleteEvent,
  KalendarView,
  LevelChangeEvent,
  MonthChangeEvent,
  SlotPressEvent,
} from '@d3sm/kalendar';
import { useCallback, useMemo, useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, useColorScheme, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

const iso = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(
    2,
    '0',
  )}`;
const nth = (n: number) => {
  const d = new Date();
  return iso(new Date(d.getFullYear(), d.getMonth(), n));
};
const today = iso(new Date());
const fmtDay = (date: string) =>
  new Date(`${date}T00:00:00`).toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });

let seq = 0;
const uid = () => `new-${seq++}`;

const PALETTE = ['#ff5c8a', '#f59e0b', '#facc15', '#22c55e', '#0ea5e9', '#8b5cf6'];

const initialEvents: KalendarEvent[] = [
  {
    id: 'e1',
    date: nth(15),
    start: '09:30',
    end: '10:30',
    title: 'Design review',
    color: '#8b5cf6',
  },
  { id: 'e2', date: nth(15), start: '12:00', end: '13:00', title: 'Lunch', color: '#f59e0b' },
  { id: 'e3', date: today, start: '11:00', end: '11:30', title: 'Standup', color: '#14b8a6' },
  { id: 'e4', date: today, start: '14:00', end: '15:30', title: 'Focus', color: '#f43f5e' },
  { id: 'md1', date: nth(14), endDate: nth(16), title: 'Retrospective', color: '#0ea5e9' },
  { id: 'ad1', date: nth(15), allDay: true, title: 'Holiday', color: '#22c55e' },
];

const coversDay = (ev: KalendarEvent, key: string) =>
  ev.date <= key && key <= (ev.endDate ?? ev.date);

export default function App() {
  const scheme = useColorScheme();
  const dark = scheme === 'dark';
  const sheet = useRef<TrueSheet>(null);
  const [selectedDate, setSelectedDate] = useState<string | undefined>(today);
  const [level, setLevel] = useState<KalendarLevel>('month');
  const [month, setMonth] = useState(today);
  const [events, setEvents] = useState(initialEvents);
  const [dayKey, setDayKey] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);

  const dayEvents = useMemo(
    () =>
      dayKey
        ? events
            .filter((e) => coversDay(e, dayKey))
            .sort(
              (a, b) =>
                Number(!!b.allDay) - Number(!!a.allDay) ||
                (a.start ?? '').localeCompare(b.start ?? ''),
            )
        : [],
    [dayKey, events],
  );
  const editing = events.find((e) => e.id === editingId) ?? null;

  const addEvent = useCallback((date: string) => {
    const id = uid();
    setEvents((prev) => [
      ...prev,
      { id, date, start: '09:00', end: '10:00', title: 'New event', color: '#6366f1' },
    ]);
    setEditingId(id);
  }, []);
  const patchEvent = useCallback((id: string, patch: Partial<KalendarEvent>) => {
    setEvents((prev) => prev.map((e) => (e.id === id ? { ...e, ...patch } : e)));
  }, []);
  const deleteEvent = useCallback((id?: string) => {
    if (id == null) return;
    setEvents((prev) => prev.filter((e) => e.id !== id));
  }, []);

  const onDayPress = useCallback((e: DayPressEvent) => {
    setSelectedDate(e.nativeEvent.date);
    setDayKey(e.nativeEvent.date);
    setEditingId(null);
    sheet.current?.present();
  }, []);
  const onLevelChange = useCallback((e: LevelChangeEvent) => setLevel(e.nativeEvent.level), []);
  const onMonthChange = useCallback((e: MonthChangeEvent) => setMonth(e.nativeEvent.month), []);
  const onDayLongPress = useCallback(
    (e: DayPressEvent) => addEvent(e.nativeEvent.date),
    [addEvent],
  );
  const onSlotPress = useCallback((e: SlotPressEvent) => addEvent(e.nativeEvent.date), [addEvent]);
  const onEventChange = useCallback(
    (e: EventChangeEvent) => {
      const { id, title, start, end, color, allDay } = e.nativeEvent;
      if (id == null) return;
      patchEvent(id, { title, start, end, allDay, ...(color ? { color } : {}) });
    },
    [patchEvent],
  );
  const onEventDelete = useCallback(
    (e: EventDeleteEvent) => deleteEvent(e.nativeEvent.id),
    [deleteEvent],
  );

  return (
    <SafeAreaProvider>
      <SafeAreaView style={[styles.root, { backgroundColor: dark ? '#000000' : '#FFFFFF' }]}>
        <KalendarView
          style={styles.cal}
          month={month}
          level={level}
          selectedDate={selectedDate}
          yearView
          scroll='continuous'
          eventEditor
          events={events}
          onDayPress={onDayPress}
          onLevelChange={onLevelChange}
          onMonthChange={onMonthChange}
          onDayLongPress={onDayLongPress}
          onSlotPress={onSlotPress}
          onEventChange={onEventChange}
          onEventDelete={onEventDelete}
        />
      </SafeAreaView>

      <TrueSheet
        ref={sheet}
        sizes={['auto', 'large']}
        cornerRadius={24}
        backgroundColor={dark ? '#1c1c1e' : '#ffffff'}>
        <View style={styles.sheet}>
          {editing ? (
            <EditForm
              key={editing.id}
              event={editing}
              dark={dark}
              onCancel={() => setEditingId(null)}
              onDelete={() => {
                deleteEvent(editing.id);
                setEditingId(null);
              }}
              onSave={(patch) => {
                if (editing.id) patchEvent(editing.id, patch);
                setEditingId(null);
              }}
            />
          ) : (
            <>
              <View style={styles.header}>
                <Text style={[styles.title, { color: dark ? '#ffffff' : '#000000' }]}>
                  {dayKey ? fmtDay(dayKey) : ''}
                </Text>

                <Pressable
                  onPress={() => dayKey && addEvent(dayKey)}
                  hitSlop={8}
                  style={styles.addBtn}>
                  <Text style={styles.addBtnText}>＋ Add</Text>
                </Pressable>
              </View>

              {dayEvents.length === 0 ? (
                <Text style={styles.muted}>Nothing scheduled — tap Add</Text>
              ) : (
                dayEvents.map((ev) => (
                  <Pressable
                    key={ev.id}
                    onPress={() => setEditingId(ev.id ?? null)}
                    style={styles.row}>
                    <View style={[styles.bar, { backgroundColor: ev.color ?? '#6366f1' }]} />

                    <View style={styles.rowText}>
                      <Text style={[styles.eventTitle, { color: dark ? '#ffffff' : '#000000' }]}>
                        {ev.title}
                      </Text>

                      <Text style={styles.eventTime}>
                        {ev.allDay || (!ev.start && !ev.end) ? 'All-day' : `${ev.start} – ${ev.end}`}
                      </Text>
                    </View>

                    <Text style={styles.chevron}>›</Text>
                  </Pressable>
                ))
              )}
            </>
          )}
        </View>
      </TrueSheet>
    </SafeAreaProvider>
  );
}

function EditForm(props: {
  event: KalendarEvent;
  dark: boolean;
  onSave: (patch: Partial<KalendarEvent>) => void;
  onDelete: () => void;
  onCancel: () => void;
}) {
  const { event, dark, onSave, onDelete, onCancel } = props;
  const [title, setTitle] = useState(event.title);
  const [start, setStart] = useState(event.start ?? '09:00');
  const [end, setEnd] = useState(event.end ?? '10:00');
  const [color, setColor] = useState(event.color ?? '#6366f1');
  const fg = dark ? '#ffffff' : '#000000';
  const field = { backgroundColor: dark ? '#2c2c2e' : '#f2f2f7', color: fg };

  return (
    <View>
      <Text style={[styles.title, { color: fg, marginBottom: 16 }]}>Edit event</Text>

      <Text style={styles.label}>Title</Text>
      <TextInput
        value={title}
        onChangeText={setTitle}
        placeholder='Title'
        placeholderTextColor='#8e8e93'
        style={[styles.input, field]}
      />

      <View style={styles.timeRow}>
        <View style={styles.flex}>
          <Text style={styles.label}>Start</Text>
          <TextInput
            value={start}
            onChangeText={setStart}
            placeholder='09:00'
            placeholderTextColor='#8e8e93'
            style={[styles.input, field]}
          />
        </View>

        <View style={styles.flex}>
          <Text style={styles.label}>End</Text>
          <TextInput
            value={end}
            onChangeText={setEnd}
            placeholder='10:00'
            placeholderTextColor='#8e8e93'
            style={[styles.input, field]}
          />
        </View>
      </View>

      <Text style={styles.label}>Color</Text>
      <View style={styles.swatches}>
        {PALETTE.map((c) => (
          <Pressable
            key={c}
            onPress={() => setColor(c)}
            style={[styles.swatch, { backgroundColor: c }, color === c && styles.swatchActive]}
          />
        ))}
      </View>

      <View style={styles.formActions}>
        <Pressable onPress={onDelete} hitSlop={8}>
          <Text style={styles.delText}>Delete</Text>
        </Pressable>

        <View style={styles.formActionsRight}>
          <Pressable onPress={onCancel} hitSlop={8}>
            <Text style={styles.cancelText}>Cancel</Text>
          </Pressable>

          <Pressable
            onPress={() => onSave({ title, start, end, color, allDay: false })}
            hitSlop={8}>
            <Text style={styles.saveText}>Save</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  cal: { flex: 1 },
  flex: { flex: 1 },
  sheet: { paddingHorizontal: 20, paddingTop: 20, paddingBottom: 40 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  title: { fontSize: 22, fontWeight: '700' },
  addBtn: {
    backgroundColor: '#6366f1',
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 999,
  },
  addBtnText: { color: '#ffffff', fontSize: 14, fontWeight: '600' },
  muted: { color: '#8e8e93', fontSize: 15, paddingVertical: 8 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 9 },
  bar: { width: 4, alignSelf: 'stretch', minHeight: 36, borderRadius: 2 },
  rowText: { flex: 1 },
  eventTitle: { fontSize: 16, fontWeight: '600' },
  eventTime: { color: '#8e8e93', fontSize: 13, marginTop: 2 },
  chevron: { color: '#c7c7cc', fontSize: 24, fontWeight: '300' },
  label: { color: '#8e8e93', fontSize: 12, fontWeight: '600', marginBottom: 6, marginTop: 4 },
  input: {
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    marginBottom: 12,
  },
  timeRow: { flexDirection: 'row', gap: 12 },
  swatches: { flexDirection: 'row', gap: 12, marginBottom: 20 },
  swatch: { width: 30, height: 30, borderRadius: 15 },
  swatchActive: { borderWidth: 3, borderColor: '#ffffff' },
  formActions: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  formActionsRight: { flexDirection: 'row', gap: 20, alignItems: 'center' },
  delText: { color: '#f43f5e', fontSize: 15, fontWeight: '600' },
  cancelText: { color: '#8e8e93', fontSize: 15, fontWeight: '600' },
  saveText: { color: '#6366f1', fontSize: 15, fontWeight: '700' },
});
