// OOP-Style Component Base Classes
import React from 'react';

/**
 * Base component class with lifecycle methods
 */
export abstract class BaseComponent<P = {}, S = {}> extends React.PureComponent<P, S> {
    protected displayName: string = 'BaseComponent';

    /**
     * Called when component mounts - override in subclasses
     */
    protected onComponentMount(): void {
        // Override in child classes
    }

    /**
     * Called when component unmounts - override in subclasses
     */
    protected onComponentUnmount(): void {
        // Override in child classes
    }

    /**
     * Lifecycle method
     */
    componentDidMount(): void {
        this.onComponentMount();
    }

    /**
     * Lifecycle method
     */
    componentWillUnmount(): void {
        this.onComponentUnmount();
    }

    /**
     * Error boundary
     */
    componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
        console.error(`${this.displayName} Error:`, error, errorInfo);
    }
}

/**
 * Functional Component Base with Hooks
 */
export interface FunctionalComponentOptions {
    displayName?: string;
    shouldRemountOnPropsChange?: boolean;
}

/**
 * Abstract base for functional components with common patterns
 */
export class ComponentController<P = {}> {
    protected displayName: string = 'ComponentController';
    protected options: FunctionalComponentOptions;

    constructor(options: FunctionalComponentOptions = {}) {
        this.options = {
            shouldRemountOnPropsChange: false,
            ...options,
        };
        this.displayName = options.displayName || 'ComponentController';
    }

    /**
     * Handle errors with logging
     */
    handleError(error: unknown, context: string): void {
        console.error(`${this.displayName} [${context}]:`, error);
    }

    /**
     * Validate props
     */
    validateProps(props: P): boolean {
        return true; // Override in subclasses
    }

    /**
     * Get display name for debugging
     */
    getDisplayName(): string {
        return this.displayName;
    }
}

/**
 * Layout Component Base
 */
export abstract class LayoutComponent<P = {}, S = {}> extends BaseComponent<P, S> {
    protected abstract renderHeader(): React.ReactNode;
    protected abstract renderContent(): React.ReactNode;
    protected abstract renderFooter?: () => React.ReactNode;

    render(): React.ReactNode {
        return (
            <div className= "layout-component" >
            <header className="layout-header" >
                { this.renderHeader() }
                </header>
                < main className = "layout-content" >
                    { this.renderContent() }
                    </main>
        {
            this.renderFooter && (
                <footer className="layout-footer" >
                    { this.renderFooter() }
                    </footer>
        )
        }
        </div>
    );
    }
}

/**
 * DataFetch Component Base - for components that fetch data
 */
export interface DataFetchState<T> {
    data: T | null;
    isLoading: boolean;
    error: Error | null;
}

export abstract class DataFetchComponent<P = {}, T = any> extends BaseComponent<
    P,
    DataFetchState<T>
> {
    constructor(props: P) {
        super(props);
        this.state = {
            data: null,
            isLoading: false,
            error: null,
        };
    }

    /**
     * Abstract method to fetch data - override in subclasses
     */
    protected abstract fetchData(): Promise<T>;

    /**
     * Set loading state
     */
    protected setLoading(isLoading: boolean): void {
        this.setState({ isLoading });
    }

    /**
     * Set error state
     */
    protected setError(error: Error | null): void {
        this.setState({ error });
    }

    /**
     * Set data state
     */
    protected setData(data: T): void {
        this.setState({ data, error: null });
    }

    /**
     * Load data safely
     */
    protected async loadData(): Promise<void> {
        try {
            this.setLoading(true);
            const data = await this.fetchData();
            this.setData(data);
        } catch (error) {
            this.setError(
                error instanceof Error ? error : new Error('Unknown error occurred')
            );
        } finally {
            this.setLoading(false);
        }
    }
}
