/**
 * Class demonstrates programatic binding configuration (as apposed to via Binding__mdt)
 *   Roughly based on the Java API. This class can be given to an Injector instance
 *     or registered via Binding__mdt and thus available to the global scope Injector
 **/
public class ForceApp3Module extends Module {
    
    public override void configure() {

        // Example SObject binding (can be used by trigger frameworks, see force-di-demo-trigger)
        bind(Account.getSObjectType()).sequence(20).to(CheckBalanceAccountTrigger.class);

        // Example named binding to a Lightning component
        bind('actionWidgetManage').lightningComponent().to('wdigetManager');

        // Example named binding to a Visualforce component (via Provider)
        bind('layoutWidgetInfo').visualforceComponent().to(WidgetInfoController.Provider.class);
    }
}
