#include <Library/Events/Event.mqh>
#include <Library/EventListener.mqh>

class IBosListener : public IEventListener {
  public:
    virtual void OnEvent(Event& event) override {
        if (event.type == EVENT_BOS)
            OnBos(event.price, event.time);
    }

    virtual void OnBos(double price, datetime time) {
    }
};

class IChochListener : public IEventListener {
  public:
    virtual void OnEvent(Event& event) override {
        if (event.type == EVENT_CHOCH)
            OnChoch(event.price, event.time);
    }

    virtual void OnChoch(double price, datetime time) {
    }
};

class BosPrintListener : public IBosListener {
  public:
    virtual void OnBos(double price, datetime time) override {
        PrintFormat("BOS price=%.5f time=%s", price, TimeToString(time));
    }
};
