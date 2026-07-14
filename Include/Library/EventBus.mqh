#include <Library/Events/Event.mqh>
#include <Library/EventListener.mqh>

class EventBus {
  private:
    IEventListener* listeners[];
    int count;

  public:
    EventBus() {
        count = 0;
    }

    void Subscribe(IEventListener& listener) {
        ArrayResize(listeners, count + 1);
        listeners[count] = &listener;
        count++;
    }

    void Publish(Event& event) {
        for (int i = 0; i < count; i++) {
            listeners[i].OnEvent(event);
        }
    }
};