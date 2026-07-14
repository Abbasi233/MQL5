enum EventType
{
   EVENT_BOS,
   EVENT_CHOCH,
   EVENT_BUTTON_CLICK
};

class Event
{
public:
   EventType type;
   double price;
   datetime time;

   Event(EventType t, double p, datetime tm)
   {
      type = t;
      price = p;
      time = tm;
   }
};