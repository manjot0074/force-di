/**
 * Copyright (c) 2018, Andrew Fawcett
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the Andrew Fawcett, nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

/**
 * Wrap a binding config to subclass it and aid in resolving target binding 
 *   (also leverages the Provider interface to allow for more advanced instantiation)
 **/
public abstract class Binding implements Comparable {

    public BindingType BindingType {get;set;}
    public String NamespacePrefix {get;set;}
    public String DeveloperName {get;set;}
    public SObjectType BindingObject {get;set;}
    public Integer BindingSequence {get;set;}
    public String To {get;set;}

    /**
     * Gets the instance of the thing the binding points to
     **/
    public Object getInstance() {
        return getInstance(null);
    }

    /**
     * Gets the instance of the thing the binding points to
     **/
    public abstract Object getInstance(Object params);

    /**
     * Compare to impl to help sorted multiple matching bindings from the resolver
     *   See toString()
     **/
    public Integer compareTo(Object compareTo) {
        Binding binding = (Binding) compareTo;
        return this.toString().compareTo(binding.toString());        
    }

    /**
     * Calcualted based on binding object and sequence if specified
     **/
    public override String toString() {
        if(BindingObject!=null) {
            String hashValue = BindingObject.getDescribe().getName();
            if(BindingSequence!=null) {
                hashValue+= '#'+BindingSequence;
            }
            return hashValue;
        } else {
            return DeveloperName;
        }
    }

    /**
    * Allows bindings to resolve dynamically (e.g. custom constructors) based passing in params if needed
    **/
    public interface Provider {
        Object newInstance(Object params);
    }

    /**
     * Simple fluent API to resolve Bindings, used by Injector methods or called directly
     **/
    public class Resolver {

        // Filter params for resolving bindings
        private String qualifiedDeveloperName;
        private SObjectType sObjectType;

        // Discovered bindings via the modules supplied to this resolver
        private List<Binding> bindings = new List<Binding>();

        public Resolver(List<Module> modules) {
            // Ask each module to configure and aggregate the resulting bindings            
            for(Module module : modules) {
                module.configure();
                bindings.addAll(module.getBindings());
            }
        }

        /**
         * Resolve by name
         **/
        public Resolver byName(String qualifiedDeveloperName) {
            this.qualifiedDeveloperName = qualifiedDeveloperName;
            return this;
        }

        /**
         * Resolve by object type
         **/
        public Resolver bySObject(SObjectType sobjectType) {
            return this;
        }

        /**
         * Returns a filtered and sorted list of known bindings
         **/
        public List<Binding> get() {
            List<Binding> matchedBindings = new List<Binding>();
            this.qualifiedDeveloperName = null;
            this.sObjectType = null;
            bindings.sort();
            return bindings;
        }
    }

    public class BindingException extends Exception {}

    public enum BindingType { Apex, VisualforceComponent, LightningComponent, Module }

    /**
     * Returns the applicable Binding impl to resolve the type of binding provided
     **/
    public static Binding newInstance(BindingType bindType) {
        // Return an applicable Binding subclass for the given binding type
        Binding binding = null;
        if(bindType == BindingType.Apex || 
           bindType == BindingType.Module) {
            binding = new ApexBinding();
        } else if(bindType == BindingType.LightningComponent) {
            binding = new LightningComponentBinding();
        } else if(bindType == BindingType.VisualforceComponent) {
            binding = new VisualForceComponentBinding();
        }
        if(binding!=null) {
            binding.BindingType = bindType;
        }
        return binding;
    }

    /**
     * Bindings to Apex classes (optionally via Provider interface)
     **/
    private class ApexBinding extends Binding {
        public override Object getInstance(Object params) {
            // Apex bindings honour the namespace of the defining custom metadata type record
            Type toType = NameSpacePrefix==null ? Type.forName(To) : Type.forName(NamespacePrefix, To);
            if(toType==null) {
                throw new BindingException('Apex binding ' + DeveloperName + ' implementation ' + To + ' does not exist');
            }
            Object toObject = toType.newInstance();
            // Is this Apex binding resolved via a Provider?
            if(toObject instanceof Provider) {
                return ((Provider) toObject).newInstance(params);
            } else if(params!=null) {
                // Params supplied but the binding does not reference a Provider?
                throw new BindingException('Apex binding ' + DeveloperName + ' implementation ' + To + ' does not implement the Provider interaface.'); 
            }
            return toObject;
        }
    }

    /**
     * Bindings to VF Components via Provider interface
     **/
    private class VisualForceComponentBinding extends Binding {
        public  override Object getInstance(Object params) {
            // Visualforce Components references must be made via an Apex class implementing the Provider interface
            Type toType = NamespacePrefix==null ? Type.forName(To) : Type.forName(NamespacePrefix, To);
            if(toType==null) {
                throw new BindingException('Visualforce Component binding ' + DeveloperName + ' implementation ' + To + ' does not exist.');
            }
            // Visualforce Components have to be resolved via a Provider
            Object toObject = toType.newInstance();
            if(toObject instanceof Provider) {
                return ((Provider) toObject).newInstance(params);
            }
            throw new BindingException('Visualforce Component binding ' + DeveloperName + ' must point to a class implementing the Provider interface.');
        }
    }

    /**
     * Bindings to Lightning Components (Provider interface not currently supported)
     **/
    private class LightningComponentBinding extends Binding {
        public  override Object getInstance(Object params) {
            // Lightning Component bindings are resolve by the Lightning Component 'inject' included in this library
            return To;
        }
    }
}
